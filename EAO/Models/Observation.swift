//
//  Observation.swift
//  EAO
//
//  Created by Evgeny Yagrushkin on 2019-01-05.
//  Copyright © 2019 Province of British Columbia. All rights reserved.
//

import ObjectMapper
import RealmSwift

class Observation: Object, Mappable{
    
    private struct SerializationKeys {
        static let id = "id"
        static let inspectionId = "inspectionId"
        static let title = "title"
        static let requirement = "requirement"
        static let coordinate = "coordinate"
        static let pinnedAt = "pinnedAt"
        static let observationDescription = "observationDescription"
    }
    
    // MARK: Properties
    @objc dynamic var id           : String = UUID().uuidString
    @objc dynamic var inspectionId : String?
    @objc dynamic var title        : String?
    @objc dynamic var requirement  : String?
    @objc dynamic var coordinate   : RealmLocation?
    @objc dynamic var pinnedAt     : Date?
    @objc dynamic var observationDescription: String?
    
    @objc dynamic var createdAt: Date = Date()
    @objc dynamic var modifiedAt: Date = Date()
    
    required convenience init?(map: Map) {
        self.init()
    }
    
    override static func primaryKey() -> String? {
        return "id"
    }
    
    func mapping(map: Map) {
        
        id <- map[SerializationKeys.id]
        inspectionId <- map[SerializationKeys.inspectionId]
        title <- map[SerializationKeys.title]
        requirement <- map[SerializationKeys.requirement]
        coordinate <- map[SerializationKeys.coordinate]
        pinnedAt <- (map[SerializationKeys.pinnedAt], DateFormatterTransform(dateFormatter: Settings.formatter))
        observationDescription <- map[SerializationKeys.observationDescription]
    }
    
    override var debugDescription: String{
        
        var parameters = [String: Any?]()
        
        parameters["title"] = title ?? "N/A"
        parameters["inspectionId"] = inspectionId
        parameters["requirement"] = requirement ?? "N/A"
        parameters["observationDescription"] = observationDescription ?? "N/A"
        return "\(self) \(parameters)"
    }
    
}
