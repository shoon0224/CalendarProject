//
//  Schedule.swift
//  CalendarProject
//
//  Created by 이상훈 on 03/06/2019.
//  Copyright © 2019 이상훈. All rights reserved.
//

import Foundation

class Schedule {
    var startDate: String?
    var schedule: String?
//  var endDate: String?
    
    init(startDate: String?, schedule: String?) {
        self.startDate = startDate
        self.schedule = schedule
    }
    
    init(schedule: String?) {
        self.schedule = schedule
    }
}
