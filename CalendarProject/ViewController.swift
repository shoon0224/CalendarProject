//
//  ViewController.swift
//  CalendarProject
//
//  Created by 이상훈 on 29/05/2019.
//  Copyright © 2019 이상훈. All rights reserved.
//

import UIKit
import FSCalendar //FSCalendar 오픈소스 받아옴
import SQLite3 //DB사용
import EventKit

class ViewController: UIViewController, FSCalendarDelegate, FSCalendarDataSource, UITableViewDelegate, UITableViewDataSource {
    
    
    
    let fileUrl = try! FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false).appendingPathComponent("CalendarData.sqlite")
    var db: OpaquePointer?
    var scheduleList = [Schedule]()
    var selectedDate: String = ""
    var delete: String = ""
    var id1: Int = 0
    
    fileprivate let gregorian: NSCalendar! = NSCalendar(calendarIdentifier:NSCalendar.Identifier.gregorian) //'오늘' 날짜가 담겨있음
    
    
    @IBOutlet weak var calendar: FSCalendar! //달력UI
    @IBOutlet weak var lbDate: UILabel! //날짜 아울렛
    @IBOutlet weak var tfSchedule: UITextField! //일정 입력하는 텍스트필드  아울렛
    @IBOutlet weak var tvSchedule: UITableView! //테이블뷰 아울렛
    
 
    
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    
        
//      calendar.scrollDirection = .vertical //세로로 스크롤
        lbDate.text = "날짜 : " //날짜 label 값 초기화
        calendar.appearance.headerDateFormat = "yyyy MMM " // 달력위 헤더데이터를 설정(yyyy MMM -> 2019 JUL)
        calendar.allowsMultipleSelection = true// 날짜를 여러개 선택 가능
        calendar.swipeToChooseGesture.isEnabled = true //여러날짜 스와이프 가능
        calendar.appearance.borderRadius = 0 // 날짜 선택시 사각형(0), 원 (2)
        self.calendar.appearance.headerMinimumDissolvedAlpha = 0.0;// 헤더 사이드에 뿌옇게 다음달미리 나타나는 것 제거
        calendar.delegate = self//필수(없으면 안됨)
        calendar.dataSource = self//필수(없으면 안됨)
        tvSchedule.delegate = self//DB를 위해
        tvSchedule.dataSource = self//DB를 위해
        
        
        
          //당겨올려짐 (문제 올리고 놓으면 이제 말을 안들음)
//        let scopeGesture = UIPanGestureRecognizer(target: calendar, action: #selector(calendar.handleScopeGesture(_:)))
//        calendar.addGestureRecognizer(scopeGesture)
        

        if sqlite3_open(fileUrl.path, &db) != SQLITE_OK { //DB 읽기
            print("error opening database")
        }
        else {
            print("DB path : " + fileUrl.path)
        }
        
        readValue()
        
    }

    //처음사용시 테이블 만들기
    @IBAction func btnCreate_clicked(_ sender: UIButton) {
        if sqlite3_exec(db, "Create table if not exists Timetables (id Integer primary key autoincrement, startDate Text, dateSchedule Text)", nil, nil, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error creating table : \(errmsg)")
        }
        else {
            print("create table OK!")
        }
    }
    
    
    @IBAction func btnSave_clicked(_ sender: UIButton) { //일정 입력 버튼 눌렸을 시
        
        
        let dSchedule = tfSchedule.text?.trimmingCharacters(in: .whitespacesAndNewlines)
        if (dSchedule?.isEmpty)! {
            tfSchedule.layer.borderColor = UIColor.red.cgColor
            tfSchedule.layer.borderWidth = 1
            return
        }
        
        var stmt:OpaquePointer?
        let queryString = "Insert into Timetables (startDate, dateSchedule)values(?, ?)"
        
        if sqlite3_prepare(db, queryString, -1, &stmt, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("error preparing insert : \(errmsg)")
            return
        }
        if sqlite3_bind_text(stmt, 1, selectedDate, -1, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure binding schedule : \(errmsg)")
            return
        }
        
        if sqlite3_bind_text(stmt, 2, dSchedule, -1, nil) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure binding schedule : \(errmsg)")
            return
        }
        
        //        if sqlite3_bind_int(stmt, 2, (rank! as NSString).intValue) != SQLITE_OK {
        //            let errmsg = String(cString: sqlite3_errmsg(db)!)
        //            print("failure binding rank : \(errmsg)")
        //            return
        //        }
        
        if sqlite3_step(stmt) != SQLITE_OK {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure inserting data : \(errmsg)")
            //return
        }
        
        tfSchedule.text = ""
        //        tfRank.text = ""
        tfSchedule.becomeFirstResponder()
        print("Data save successfully")
        readValue()
    }
    
    
    //삭제하기
    func tableView(_ tableView:UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {

        print("삭제구문입니다.")
        if editingStyle == .delete {
            let todo:Schedule = scheduleList[indexPath.row]
            delete = todo.schedule!
            scheduleList.remove(at: (indexPath as NSIndexPath).row)
            tableView.deleteRows(at: [indexPath], with: .fade)

            let del = delete.trimmingCharacters(in: .whitespacesAndNewlines)
            let queryString = "DELETE from Timetables WHERE dateSchedule = ?"   //삭제 쿼리문
            var stmt:OpaquePointer?;

            if sqlite3_prepare(db, queryString, -1,  &stmt, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("failure preparing select : \(errmsg)")
                return
            }
            if sqlite3_bind_text(stmt, 1, del, -1, nil) != SQLITE_OK {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("failure binding delete : \(errmsg)")
                return
            }
            print("select data : " + selectedDate) // 현재 선택된 날 프린트
            print("delete data : " + delete)    //선택된 일정 프린트

            if sqlite3_step(stmt) != SQLITE_DONE {
                let errmsg = String(cString: sqlite3_errmsg(db)!)
                print("failure binding deleting : \(errmsg)")
                return
            }
        }
        tvSchedule.reloadData()
    }
    
    func readValue() { //DB 읽어오기
        scheduleList.removeAll()

        let queryString = "Select dateSchedule from Timetables WHERE startDate = '\(selectedDate)'"
        var stmt:OpaquePointer?

        if sqlite3_prepare(db, queryString, -1,  &stmt, nil) == SQLITE_OK {

            while(sqlite3_step(stmt) == SQLITE_ROW) {
                let dSchedule = String(cString: sqlite3_column_text(stmt, 0))
              // _ = String(cString: sqlite3_column_text(stmt, 1))
                //                let powerrank = sqlite3_column_int(stmt, 2)
                scheduleList.append(Schedule(schedule: String(describing: dSchedule)))
            }
            print("select data : \(scheduleList)")
        }
        else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure preparing select : \(errmsg)")
            return
        }
        tvSchedule.reloadData()
    }
    
    
    

    
    
    
    
    
    //테이블뷰 리스트 개수 카운팅하는 부분.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scheduleList.count
    }
    
    //테이블뷰에 리스트 띄우는부분
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell:UITableViewCell?
        cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let todo:Schedule = scheduleList[indexPath.row]
        cell!.textLabel?.text = "\(String(describing: todo.schedule!))"
        return cell!
    }
    
    
    
    
    
    //일정 있는 날에 도트찍기
    func calendar(_ calendar: FSCalendar, numberOfEventsFor date: Date) -> Int {
        selectedDate = self.dateFormatter.string(from: date)//하루하루 다 읽어온다. (비효율적이긴 하지만 어쩔 수 없다.)

        if (selectCalDate(selectedDate).count > 0) {
            return 1 //일정이 있으면 하나만찍는다.
        }
        return 0
    }
    
    
    
    
    
    
    
     //오늘 날짜 아래에 "오늘"이라고 기입 !!노란줄 없애지마시오!!
    func calendar(_ calendar: FSCalendar!, subtitleFor date: Date?) -> String! {
        if self.gregorian.isDateInToday(date!){
            return "오늘"
        }
        return nil
    } //날짜들 아래에 문자열 기입, 이미지도 기입 가능, 노란경고 떠도 바꾸지 말것 혹시 실수로 바꿔어 소스 분실시 아래 소스코드 쓰기
        //    func calendar(_ calendar: FSCalendar!, subtitleFor date: Date?) -> String! {
        //        if self.gregorian.isDateInToday(date!){
        //            return "오늘"
        //        }
        //        return nil
        //    }
    
    
    
    
    
    
    // 해당 날짜 데이터를 갖고있음
    fileprivate lazy var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 MM월 dd일"
        return formatter
    }()
    
    
    
    // 특정 날짜를 선택했을 때, 발생하는 이벤트
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        
        selectedDate = self.dateFormatter.string(from: date)
        
        print("did select date \(self.dateFormatter.string(from: date))") //마지막 선택 날짜만 출력
        let selectedDates = calendar.selectedDates.map({self.dateFormatter.string(from: $0)})
        print("selected dates is \(selectedDates)") //드래그된 모든 날짜 출력
        if monthPosition == .next || monthPosition == .previous {
            calendar.setCurrentPage(date, animated: true)
        }// 콘솔창에 해당날짜 클릭시 날짜 프린트
        
        scheduleList.removeAll()
        
        let queryString = "Select dateSchedule from Timetables WHERE startDate = '\(selectedDate)'"
        var stmt:OpaquePointer?
        
        if sqlite3_prepare(db, queryString, -1,  &stmt, nil) == SQLITE_OK {
            
            while(sqlite3_step(stmt) == SQLITE_ROW) {
                let dSchedule = String(cString: sqlite3_column_text(stmt, 0))
                // _ = String(cString: sqlite3_column_text(stmt, 1))
                //                let powerrank = sqlite3_column_int(stmt, 2)
                scheduleList.append(Schedule(schedule: String(describing: dSchedule)))
            }
            print("select data : \(scheduleList)")
        }
        else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure preparing select : \(errmsg)")
            return
        }
        tvSchedule.reloadData()
        
        lbDate.text = "날짜 : " + self.dateFormatter.string(from: date) //특정 날짜 클릭시 레이블에 날짜 표시
        
        
                //해당 날짜 클릭시 알럿으로 일정 추가하기
//            let alertController = UIAlertController(title: "일정 추가", message: self.dateFormatter.string(from: date), preferredStyle: .alert)
//            alertController.addTextField { (UITextField)  in UITextField.placeholder = "일정을 입력하세요"
//            }
//        let confirmAction = UIAlertAction(title: "확인", style: .default)  {_ in _ = alertController.textFields![0]
//            }
//            let cancelAction = UIAlertAction(title: "취소", style: .cancel){_ in}
//            alertController.addAction(confirmAction)
//            alertController.addAction(cancelAction)
//            self.present(alertController,animated: true,completion: nil)
       
        
        }
    
    
    // 스와이프를 통해서 다른 달(month)의 달력으로 넘어갈 때 발생하는 이벤트
    private func calendarCurrentMonthDidChange(calendar: FSCalendar) {
        
    }
    
    
    
    
    //이벤트 도트 찍는것, 테스트했는데 아직 구동안됨
    func calendar(calendar: FSCalendar!, hasEventForDate date: NSDate!) -> Bool {
        return false
    }
    
    
    
    //일정이 들어간 날만 불러오는 함수
    func selectCalDate(_ selectedDate: String) -> [Schedule]{
        var schedules = [Schedule]()
        let queryString = "Select dateSchedule from Timetables WHERE startDate = '\(selectedDate)'"
        
        var stmt:OpaquePointer?
        
        if sqlite3_prepare(db, queryString, -1,  &stmt, nil) == SQLITE_OK {
            
            while(sqlite3_step(stmt) == SQLITE_ROW) {
                let dSchedule = String(cString: sqlite3_column_text(stmt, 0))
                // _ = String(cString: sqlite3_column_text(stmt, 1))
                //                let powerrank = sqlite3_column_int(stmt, 2)
                schedules.append(Schedule(schedule: String(describing: dSchedule)))
            }
            print("select data : \(schedules)")
            return schedules
        }
        else {
            let errmsg = String(cString: sqlite3_errmsg(db)!)
            print("failure preparing select : \(errmsg)")
        }
        return schedules
    }
    
}
    
    
    
    //특정 날짜 아래에 이미지 아이콘 넣기
   /* func calendar(_ calendar: FSCalendar, imageFor date: Date) -> UIImage? {
        let day: Int! = self.gregorian.component(.day, from: date)
        return [날짜].contains(day) ? UIImage(named: "이미지 이름") : nil
    }*/


