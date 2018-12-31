//
//  PFManager.swift
//  EAO
//
//  Created by Amir Shayegh on 2018-01-16.
//  Copyright © 2018 FreshWorks. All rights reserved.
//

import Foundation
import AVFoundation
import Parse
import Photos
import RealmSwift
import Alamofire
import AlamofireObjectMapper

class DataServices {
    
    static let realmFileName = "default.realm"
    static let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

    static let shared = DataServices()

    // MARK: Realm

    internal class func setup() {
        
        DataServices.configureRealm()
    }
    
    private class func configureRealm() {
        
        let config = Realm.Configuration(fileURL: DataServices.realmPath(),
                                         schemaVersion: Settings.REALM_SCHEMA_NUMBER,
                                         migrationBlock: { migration, oldSchemaVersion in
                                            // check oldSchemaVersion here, if we're newer call
                                            // a method(s) specifically designed to migrate to
                                            // the desired schema. ie `self.migrateSchemaV0toV1(migration)`
                                            if (oldSchemaVersion < 1) {
                                                // Nothing to do. Realm will automatically remove and add fields
                                            }
        },
                                         shouldCompactOnLaunch: { totalBytes, usedBytes in
                                            // totalBytes refers to the size of the file on disk in bytes (data + free space)
                                            // usedBytes refers to the number of bytes used by data in the file
                                            
                                            // Compact if the file is over 10MB in size and less than 50% 'used'
                                            let oneHundredMB = 10 * 1024 * 1024
                                            return (totalBytes > oneHundredMB) && (Double(usedBytes) / Double(totalBytes)) < 0.5
        })
        
        Realm.Configuration.defaultConfiguration = config
    }
    
    // Allow customization of the Realm; this will let us keep it in a location that is not
    // backed up if needed.
    private class func realmPath() -> URL {
        
        var workspaceURL = URL(fileURLWithPath: DataServices.documentsURL.path, isDirectory: true).appendingPathComponent("db")
        var directory: ObjCBool = ObjCBool(false)
        
        if !FileManager.default.fileExists(atPath: workspaceURL.path, isDirectory: &directory) {
            // no backups
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = true
            
            do  {
                try FileManager.default.createDirectory(at: workspaceURL, withIntermediateDirectories: false, attributes: nil)
                try workspaceURL.setResourceValues(resourceValues)
            } catch {
                fatalError("Unable to create a location to store the database")
            }
        }
        
        return URL(fileURLWithPath: realmFileName, isDirectory: false, relativeTo: workspaceURL)
    }

    class func add(inspection: PFInspection, isStoredLocally: Bool = false) -> Bool {
        
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(inspection, update: true)
            }
            
            let doc = InspectionMeta()
            doc.id = UUID().uuidString
            doc.localId = inspection.id
            //        doc.remoteId = inspection.objectId
            doc.isStoredLocally = isStoredLocally
            doc.modifiedAt = Date()

            try realm.write {
                realm.add(doc)
            }

        } catch {
            print("\(#function) Realm error: \(error.localizedDescription)")
            return false
        }
        return true
    }

    class func add(observation: PFObservation) -> Bool {
        
        do {
            let realm = try Realm()
            try realm.write {
                realm.add(observation, update: true)
            }
        } catch let error {
            print("\(#function) Realm error: \(error.localizedDescription)")
            return false
        }
        
        return true
    }

    
    // MARK: Parse
    internal class func inspectionQueryForCurrentUser() -> PFQuery<PFObject>? {

//        guard let query = PFInspection.query() else {
//            return nil
//        }
//
//        query.whereKey("userId", equalTo: PFUser.current()!.objectId!)
//        query.fromLocalDatastore()
//        query.order(byDescending: "start")
        
//        return query
        return nil
    }
    
    internal class func fetchInspections(completion: ((_ results: [PFInspection]) -> Void)? = nil) {
        //TODO: #11
        //filter inspections by user ID
        do {
            let realm = try Realm()
            let inspections = realm.objects(PFInspection.self).sorted(byKeyPath: "title", ascending: true)
            let inspectionsArray = Array(inspections)
            
            print("fetchInspections: count = \(inspections.count)");
            completion?(inspectionsArray)
        } catch {
            completion?([])
        }
    }
    
    internal class func fetchFullInspection(inspection: PFInspection, completion: (() -> Void)? = nil) {
        
        let dispatchGroup = DispatchGroup()
        
        DataServices.fetchObservationsFor(inspection: inspection) { (results) in
            for observation in results {
                dispatchGroup.enter()
                DataServices.fetchPhotosFor(observation: observation) { _ in
                    dispatchGroup.leave()
                }
            }
            
            dispatchGroup.notify(queue: .main) {
                print("DONE FETCHING INSPECTION 👍")
                inspection.isStoredLocally = true
                completion?()
            }
        }
    }
    
    class func fetchObservations(for inspection: PFInspection) -> [PFObservation]? {
        do {
            let realm = try Realm()
            let observations = realm.objects(PFObservation.self).filter("inspectionId in %@", [inspection.id]).sorted(byKeyPath: "pinnedAt", ascending: true)
            let observationsArray = Array(observations)
            
            print("fetchObservations: count = \(observations.count)");
            return observationsArray
        } catch let error {
            print("fetchObservations: \(error.localizedDescription)");
        }
        return nil
    }
    
    internal class func fetchObservationsFor(inspection: PFInspection, localOnly: Bool = false, completion: ((_ results: [PFObservation]) -> Void)? = nil) {
        
        let observations = DataServices.fetchObservations(for: inspection)
        
//        guard let query = PFObservation.query() else {
//            completion?([])
//            return
//        }
//
//        query.whereKey("inspectionId", equalTo: inspection.id!)
//        if localOnly {
//            query.fromLocalDatastore()
//        }
//
//        query.findObjectsInBackground { (objects, error) -> Void in
//            guard let objects = objects as? [PFObservation], error == nil else {
//                completion?([])
//                return
//            }
//
//            objects.forEach({ (object) in
//                if let oid = object.id, !oid.isEmpty {
//                    object.id = UUID().uuidString // Local ID Only, must be set.
//                }
//                object.inspectionId = inspection.id!
//                if !localOnly {
//                    object.pinInBackground();
//                }
//            })
//
//            completion?(objects)
//        }
    }
    
    internal class func fetchPhotosFor(observation: PFObservation, completion: ((_ results: [PFPhoto]) -> Void)? = nil) {
        
//        guard let query = PFPhoto.query() else {
//            completion?([])
//            return
//        }
//
//        query.whereKey("observation", equalTo: observation)
//        query.findObjectsInBackground { (objects, error) -> Void in
//            guard let objects = objects as? [PFPhoto], error == nil else {
//                completion?([])
//                return
//            }
//
//            let group = DispatchGroup()
//            for (index, object) in objects.enumerated() {
//                group.enter()
//                object.id = UUID().uuidString // Local ID Only, must be set.
//                object.observationId = observation.id!
//                object.pinInBackground();
//                DataServices.fetchDataFor(photo: object, observation: observation, index: index, completion: { (data: Data?) in
//                    group.leave()
//                })
//            }
//
//            group.notify(queue: .main) {
//                // all photo data fetched
//                completion?(objects)
//            }
//        }
    }
    
    internal class func fetchDataFor(photo: PFPhoto, observation: PFObservation, index: Int, completion: ((_ result: Data?) -> Void)? = nil) {
        
//        guard let image = photo["photo"] as? PFFile else {
//            completion?(nil)
//            return
//        }
//
//        var loc: CLLocation = CLLocation(latitude: 0, longitude: 0)
//        if let lat = photo.coordinate?.latitude, let lng = photo.coordinate?.longitude {
//            loc = CLLocation(latitude: lat, longitude: lng)
//        }
//
//        if image.isDataAvailable {
//            if let imageData = try? image.getData() {
//                DataServices.savePhoto(image: UIImage(data: imageData)!, index: index, location: loc, observationID: observation.id!, description: photo.caption, completion: { (success) in
//                    completion?(imageData)
//                })
//            }
//
//            return
//        }
//
//        image.getDataInBackground(block: { (data: Data?, err: Error?) in
//            if let imageData = data {
//                DataServices.savePhoto(image: UIImage(data: imageData)!, index: index, location: loc, observationID: observation.id!, description: photo.caption, completion: { (success) in
//                    completion?(imageData)
//                })
//            }
//        })
    }
    
    internal class func deleteLocalObservations(forInspection inspection: PFInspection, completion: (() -> Void)? = nil) {
        
//        guard let query = PFObservation.query() else {
//            completion?()
//            return
//        }
//
//        query.whereKey("inspection", equalTo: inspection)
//        query.fromLocalDatastore()
//        query.findObjectsInBackground { (objects, error) -> Void in
//            DispatchQueue.global(qos: .background).async {
//                guard let objects = objects as? [PFObservation], error == nil else {
//                    return
//                }
//
//                objects.forEach({ (observation) in
//                    try? observation.unpin()
//                })
//
//                DispatchQueue.main.async {
//                    inspection.isStoredLocally = false
//                    completion?()
//                }
//            }
//        }
    }
    
    internal class func uploadInspection(inspection: PFInspection, completion: @escaping (_ done: Bool) -> Void) {
     
//        inspection["isActive"] = true // so it shows up in the EAO admin site
//        fetchObservationsFor(inspection: inspection, localOnly: true) { (results: [PFObservation]) in
//            let inspectionId = inspection.id
//            inspection["id"] = NSNull()
//            results.forEach({ (observation) in
//                observation["inspection"] = inspection
//                observation.saveInBackground(block: { (status, error) in
//                    inspection.id = inspectionId
//                    inspection.isSubmitted = true
//                    inspection.pinInBackground()
//
//                    completion(true)
//                })
//            })
//        }
    }
    
   
    // MARK: -
    
    internal class func uploadInspection2(inspection: PFInspection, completion: @escaping (_ done: Bool) -> Void) {
//        let object = PFObject(className: "Inspection")
//
//        let userId = inspection.userId ?? ""
//        let project = inspection.project ?? ""
//        let title = inspection.title ?? ""
//        let subtitle = inspection.subtitle ?? ""
//        let subtext = inspection.subtext ?? ""
//        let number = inspection.number ?? ""
//        let start = inspection.start
//        let end = inspection.end
//
//        object["userId"] = userId
//        object["project"] = project
//        object["title"] = title
//        object["subtitle"] = subtitle
//        object["subtext"] = subtext
//        object["number"] = number
//        object["start"] = start
//        object["end"] = end
//        object["uploaded"] = false
//
//        object.saveInBackground { (success, error) in
//            if success {
//                self.getObservationsFor(inspection: inspection, completion: { (success, observations) in
//                    if success {
//                        let temp: [PFObject] = [PFObject]()
//                        self.recursiveObservationUpload(observations: observations!, inspection: object, objects: temp, completion: { (success, uploadedObjects) in
//                            if success {
//                                // get team
//                                if inspection.teamID != nil && inspection.teamID != "" {
//                                    let query = PFQuery(className: "Team")
//                                    query.getObjectInBackground(withId: inspection.teamID!, block: { (teamobject, error) in
//                                        if let teamobj = teamobject {
//                                            object["team"] = teamobj
//                                            object["uploaded"] = true
//                                            object["isSubmitted"] = true
//                                            object["isActive"] = true
//                                            inspection.isSubmitted = true
//                                            inspection.pinInBackground()
//                                            object.saveInBackground(block: { (success, error) in
//                                                if success {
//                                                    return completion(true)
//                                                } else {
//                                                    return completion(false)
//                                                }
//                                            })
//                                        }
//                                    })
//                                } else {
//                                    object["uploaded"] = true
//                                    object["isSubmitted"] = true
//                                    object["isActive"] = true
//                                    inspection.isSubmitted = true
//                                    inspection.pinInBackground()
//                                    object.saveInBackground(block: { (success, error) in
//                                        if success {
//                                            return completion(true)
//                                        } else {
//                                            return completion(false)
//                                        }
//                                    })
//                                }
//                            } else {
//                                return completion(false)
//                            }
//                        })
//                    } else {
//                        return completion(false)
//                    }
//                })
//            } else {
//                return completion(false)
//            }
//        }
    }
    
    internal class func recursiveObservationUpload(observations: [PFObservation], inspection: PFObject, objects: [PFObject], completion: @escaping (_ done: Bool, _ observations: [PFObject]?) -> Void) {
//        var array = observations
//        var results = objects
//        let current = observations.last
//        array.removeLast()
//
//        uploadObserbation(observation: current!, inspection: inspection) { done, object  in
//            if done {
//                results.append(object!)
//                if !array.isEmpty && array.count > 0 {
//                    self.recursiveObservationUpload(observations: array,inspection: inspection, objects: results, completion: completion)
//                } else {
//                    return completion(true, results)
//                }
//            } else {
//                return completion(false, nil)
//            }
//        }
    }
    
    internal class func uploadObserbation(observation: PFObservation, inspection: PFObject, completion: @escaping (_ done: Bool, _ observation: PFObject?) -> Void) {
//        let object = PFObject(className: "Observation")
//
//        let title = observation.title
//        let requirement = observation.requirement ?? ""
//        let coordinate = observation.coordinate ?? PFGeoPoint()
//        let observationDescription = observation.observationDescription ?? ""
//
//        object["title"] = title
//        object["requirement"] = requirement
//        object["coordinate"] = coordinate
//        object["observationDescription"] = observationDescription
//        object["inspection"] = inspection
//
//        object.saveInBackground { (success, error) in
//            if success {
//                self.uploadVideos(for: observation, observObj: object, completion: { (done) in
//                    if done {
//                        self.uploadAudios(for: observation,  obsObj: object, completion: { (done) in
//                            if done {
//                                self.uploadPhotos(for: observation, obsObj: object, completion: { (done) in
//                                    if done {
//                                        return completion(true, object)
//                                    } else {
//                                        return completion(false, nil)
//                                    }
//                                })
//                            } else {
//                                return completion(false, nil)
//                            }
//                        })
//                    } else {
//                        return completion(false, nil)
//                    }
//                })
//            } else {
//                return completion(false, nil)
//            }
//        }
    }
    
    internal class func getObservationsFor(inspection: PFInspection, completion: @escaping (_ done: Bool, _ observations: [PFObservation]?) -> Void) {
        PFObservation.load(for: inspection.id) { (results) in
            guard let observations = results, !observations.isEmpty else{
                return completion(false, nil)
            }
            return completion(true, observations)
        }
    }
    
    // save locally
    
    internal class func uploadVideo(for observation: PFObservation, obsObj: PFObject, at index: Int, completion: @escaping (_ success: Bool, _ pfObject: PFObject? ) -> Void) {
//        let video = PFObject(className: "Video")
//
//        getVideoAt(observationID: observation.id!, at: index) { (found, pfvideo) in
//            if !found {
//                print("not found!")
//            }
//
//            let title: String = pfvideo?.title ?? ""
//            let notes: String  = pfvideo?.notes ?? ""
//            var vidIndex: Int = -1
//            if let indx = pfvideo?.index {
//                vidIndex = indx as! Int
//            }
//
//            let videoData = pfvideo?.get()
//            if videoData == nil {
//                return completion(false, nil)
//
//            }
//            let parseVideoFile = PFFile(name: "\(observation.id!)\(index).mp4", data: videoData!)
//            parseVideoFile?.saveInBackground(block: { (success, error) -> Void in
//                if success{
//                    video["title"] = title
//                    video["notes"] = notes
//                    video["index"] = vidIndex
//                    video["video"] = parseVideoFile
//                    video["observation"] = obsObj
//                    video.saveInBackground(block: { (success, error) in
//                        if success  {
//                            return completion(true, video)
//                        } else {
//                            return completion(false, nil)
//                        }
//                    })
//                } else {
//                    return completion(false, nil)
//                }
//            })
//        }
    }
    
    // count instead of array of videos because i was resuing functions: there is a function to get video at index for observation
    internal class func recursiveVideoUpload(last index: Int,for observation: PFObservation, observObj: PFObject, parseVideoObjects: [PFObject],completion: @escaping (_ done: Bool, _ videos: [PFObject]) -> Void) {
        if index > -1 {
            
            uploadVideo(for: observation, obsObj: observObj, at: index, completion: { (success, videoObjsect) in
                if success {
                    var objects = parseVideoObjects
                    objects.append(videoObjsect!)
                    
                    let nextIndex = index - 1
                    if nextIndex > -1 {
                        self.recursiveVideoUpload(last: nextIndex, for: observation, observObj: observObj, parseVideoObjects: objects, completion: completion)
                    } else {
                        // done
                        completion(true, objects)
                    }
                } else {
                    // fail
                    completion(false, parseVideoObjects)
                }
            })
        } else {
            // done
            completion(true, parseVideoObjects)
        }
    }
    
    internal class func uploadAudio(for observation: PFObservation,  obsObj: PFObject, at index: Int, completion: @escaping (_ success: Bool, _ pfObject: PFObject? ) -> Void) {
//        let audio = PFObject(className: "Audio")
//        getAudiosFor(observationID: observation.id!) { (success, audios) in
//            if success, let results = audios {
//                let current = results[index]
//                let observationId : String = current.observationId ?? ""
//                let coordinate : PFGeoPoint = current.coordinate ?? PFGeoPoint()
//                let index: Int = index
//                let notes: String = current.notes ?? ""
//                let title: String = current.title ?? ""
//                let audioData = current.get()
//                if audioData == nil { return completion(false, nil)}
//                let parseAudioFile = PFFile(name: "\(observationId)\(index).mp4a", data: audioData!)
//                parseAudioFile?.saveInBackground(block: { (success, error) -> Void in
//                    if success {
//                        audio["coordinate"] = coordinate
//                        audio["notes"] = notes
//                        audio["index"] = index
//                        audio["title"] = title
//                        audio["audio"] = parseAudioFile
//                        audio["observation"] = obsObj
//                        audio.saveInBackground(block: { (success, error) in
//                            if success  {
//                                return completion(true, audio)
//                            } else {
//                                return completion(false, nil)
//                            }
//                        })
//                    } else {
//                        return completion(false, nil)
//                    }
//                })
//            }
//        }
    }
    
    internal class func recursiveAudioUpload(last index: Int,for observation: PFObservation,  obsObj: PFObject, parseAudioObjects: [PFObject],completion: @escaping (_ done: Bool, _ audios: [PFObject]) -> Void) {
        if index > -1 {
            uploadAudio(for: observation, obsObj: obsObj, at: index, completion: { (success, audioObjsect) in
                if success {
                    var objects = parseAudioObjects
                    objects.append(audioObjsect!)
                    
                    let nextIndex = index - 1
                    if nextIndex > -1 {
                        self.recursiveAudioUpload(last: nextIndex, for: observation, obsObj: obsObj, parseAudioObjects: objects, completion: completion)
                    } else {
                        // done
                        completion(true, objects)
                    }
                } else {
                    // fail
                    completion(false, parseAudioObjects)
                }
            })
        } else {
            // done
            completion(true, parseAudioObjects)
        }
    }
    
    internal class func uploadAudios(for observation: PFObservation, obsObj: PFObject, completion: @escaping (_ success: Bool) -> Void) {
        getAudiosFor(observationID: observation.id) { (success, pfaudios) in
            if success {
                if let count = pfaudios?.count {
//                    let parseSoundObjects: [PFAudio] = [PFAudio]()
//                    self.recursiveAudioUpload(last: (count - 1), for: observation, obsObj: obsObj, parseAudioObjects: parseSoundObjects, completion: { (done, audios) in
//                        if done {
//                            return completion(true)
//                        } else {
//                            // couldnt upload
//                            return completion(false)
//                        }
//                    })
                } else {
                    // couldnt upload
                    return completion(false)
                }
            } else {
                // couldnt upload
                return completion(false)
                
            }
        }
    }
    
    internal class func uploadVideos(for observation: PFObservation, observObj: PFObject, completion: @escaping (_ success: Bool) -> Void) {
        getVideosFor(observationID: observation.id) { (success, pfvideos) in
            if success {
                if let count = pfvideos?.count {
                    let parseVideObjects: [PFObject] = [PFObject]()
                    self.recursiveVideoUpload(last: (count - 1), for: observation, observObj: observObj, parseVideoObjects: parseVideObjects, completion: { (done, videos) in
                        if done {
                            return completion(true)
                        } else {
                            // fail
                            // couldnt upload videos
                            return completion(false)
                        }
                    })
                } else {
                    // unlikely yo get here
                    return completion(false)
                }
            } else {
                // fail.
                // could npt find videos
                return completion(false)
            }
        }
    }
    
    internal class func uploadPhotos(for observation: PFObservation, obsObj: PFObject, completion: @escaping (_ success: Bool) -> Void) {
        getPhotosFor(observationID: observation.id) { (success, pfphotos) in
            if success {
                if let count = pfphotos?.count {
                    let parsePhotoObjects: [PFObject] = [PFObject]()
                    self.recursivePhotoUpload(last: (count - 1), for: observation, obsObj: obsObj, parsePhotoObjects: parsePhotoObjects, completion: { (done, photos) in
                        if done {
                            return completion(true)
                        } else {
                            // fail
                            return completion(false)
                        }
                    })
                } else {
                    return completion(false)
                }
            } else {
                return completion(false)
            }
        }
    }
    
    internal class func recursivePhotoUpload(last index: Int,for observation: PFObservation, obsObj: PFObject, parsePhotoObjects: [PFObject],completion: @escaping (_ done: Bool, _ photos: [PFObject]) -> Void) {
        if index > -1 {
            uploadPhoto(for: observation, obsObj: obsObj, at: index, completion: { (success, photoObject) in
                if success {
                    var objects = parsePhotoObjects
                    objects.append(photoObject!)
                    
                    let nextIndex = index - 1
                    if nextIndex > -1 {
                        self.recursivePhotoUpload(last: nextIndex, for: observation, obsObj: obsObj, parsePhotoObjects: objects, completion: completion)
                    } else {
                        // done
                        completion(true, objects)
                    }
                } else {
                    completion(false, parsePhotoObjects)
                }
            })
        } else {
            // done
            completion(true, parsePhotoObjects)
        }
    }
    
    
    
    internal class func uploadPhoto(for observation: PFObservation, obsObj: PFObject, at index: Int, completion: @escaping (_ success: Bool, _ pfObject: PFObject? ) -> Void) {
        
//        let photo = PFObject(className: "Photo")
//        getPhotoAt(observationID: observation.id!, at: index) { (found, pfphoto) in
//            if !found {
//                print("Not found")
//                return completion(false, nil)
//            }
//
//            let observationId : String = pfphoto?.observationId ?? ""
//            let caption       : String = pfphoto?.caption ?? ""
//            let timestamp     : Date?   = pfphoto?.timestamp ?? nil
//            let coordinate    : PFGeoPoint = pfphoto?.coordinate ?? PFGeoPoint()
//            //            let index: Int = index
//            let photoData = pfphoto?.get()
//            if photoData == nil { return completion(false, nil)}
//
//            let parsePhotoFile = PFFile(name: "\(observationId)\(index).jpeg", data: photoData!)
//            parsePhotoFile?.saveInBackground(block: { (success, error) -> Void in
//                if success {
//                    var picIndex = -1
//                    if let indx =  pfphoto?.index {
//                        picIndex = indx as! Int
//                    }
//                    photo["coordinate"] = coordinate
//                    photo["caption"] = caption
//                    photo["index"] = picIndex
//                    photo["timestamp"] = timestamp
//                    photo["photo"] = parsePhotoFile
//                    photo["observation"] = obsObj
//                    photo.saveInBackground(block: { (success, error) in
//                        if success  {
//                            return completion(true, photo)
//                        } else {
//                            return completion(false, nil)
//                        }
//                    })
//                } else {
//                    return completion(false, nil)
//                }
//            })
//        }
    }
    
    
        
    internal class func isUserMobileAccessEnabled(completion: @escaping (_ success: Bool) -> Void) {
        
        guard let user: User = PFUser.current() as? User, let id = user.objectId else {
            return completion(false)
        }

        guard let query: PFQuery = PFUser.query() else {
            return completion(false)
        }

        query.getObjectInBackground(withId: id) { (userObj, error) in
            if let obj = userObj,
                let access: [String: Any] = obj["access"] as? [String : Any],
                let mobileAccess: Bool = access["mobileAccess"] as? Bool,
                let isActive: Bool = obj["isActive"] as? Bool {
                print(access)
                if mobileAccess && isActive {
                    return completion(true)
                } else {
                    return completion(false)
                }
            } else {
                return completion(false)
            }
        }
        
    }
    
    internal class func getUserTeams(user: User, completion: @escaping (_ success: Bool,_ teams: [PFObject]) -> Void) {
        
        let query = PFQuery(className: "Team")
        var downloadedTeams = [PFObject]()
        query.whereKey("users", equalTo: user)
        query.findObjectsInBackground { (teams, error) in
            if let foundTeams: [PFObject] = teams {
                for team in foundTeams {
                    downloadedTeams.append(team)
                    team.pinInBackground()
                }
                return completion(true, downloadedTeams)
            }
            else {
                return completion(false, downloadedTeams)
            }
        }
    }
    
    internal class func getTeams(completion: @escaping (_ success: Bool, _ teams: [Team]?) -> Void) {
        
        guard let user: User = PFUser.current() as? User else {
            print("\(#function) user is missing")
            return completion(false, nil)
        }
        
        self.getUserTeams(user: user) { (done, downloaded)  in
            if done {
                var results = [Team]()
                for object: PFObject in downloaded {
                    results.append(Team(objectID: object.objectId!, name: (object["name"] as? String)!, isActive: (object["isActive"] as? Bool)!))
                }
                return completion(true, results)
            } else {
                let query = PFQuery(className: "Team")
                query.fromLocalDatastore()
                query.findObjectsInBackground { (objects, error) in
                    if objects != nil  {
                        var r = [Team]()
                        for object: PFObject in objects! {
                            r.append(Team(objectID: object.objectId!, name: (object["name"] as? String)!, isActive: (object["isActive"] as? Bool)!))
                        }
                        completion(true, r)
                    } else {
                        return completion(false, nil)
                    }
                }
            }
        }
    }
}


