//
//  WDTActivity.swift
//  Widdit
//
//  Created by Igor Kuznetsov on 20.06.16.
//  Copyright © 2016 John McCants. All rights reserved.
//

import Foundation
import Parse

class WDTActivity {
    
    enum WDTActivityType: String {
        case Down = "down"
        case Undown = "undown"
    }

    let currentUser = PFUser.current()!
    var post: PFObject?
    var chats: [Activity] = []
    var downs: [PFObject] = []
    var myDowns: [PFObject] = []
    
    static var _wdtActivity: WDTActivity? = nil
    
    static func sharedInstance() -> WDTActivity {
        if _wdtActivity == nil {
            _wdtActivity = WDTActivity()
        }
        
        return _wdtActivity!
    }
    
    class func isDown(user: PFUser, post: PFObject, completion: @escaping (_ down: PFObject?) -> Void) {
        let didDown = PFQuery(className: "Activity")
        didDown.whereKey("by", equalTo: PFUser.current()!)
        didDown.whereKey("to", equalTo: user)
        didDown.whereKey("post", equalTo: post)
        
        didDown.findObjectsInBackground(block: { (objects, error) in
            if let object = objects?.first {
                completion(object)
            } else {
                completion(nil)
            }
        })
    }
    
    class func isDownAndReverseDown(user: PFUser, post: PFObject, completion: @escaping (_ down: PFObject?) -> Void) {
        let didDown = PFQuery(className: "Activity")
        didDown.whereKey("by", equalTo: PFUser.current()!)
        didDown.whereKey("to", equalTo: user)
        didDown.whereKey("post", equalTo: post)
        
        let reverseDidDown = PFQuery(className: "Activity")
        reverseDidDown.whereKey("by", equalTo: user)
        reverseDidDown.whereKey("to", equalTo: PFUser.current()!)
        reverseDidDown.whereKey("post", equalTo: post)
        
        let allQueries = PFQuery.orQuery(withSubqueries: [didDown, reverseDidDown])
        
        allQueries.findObjectsInBackground(block: { (objects, error) in
            if let object = objects?.first {
                completion(object)
            } else {
                completion(nil)
            }
        })
    }
    
    class func addActivity(user: PFUser, post: PFObject, type: WDTActivityType, completion: @escaping (_ activityObj: PFObject) -> Void) {
        WDTPush.sendPushAfterDownTapped(toUsername: user.username!, postId: post.objectId!)
        
        WDTActivity.isDown(user: user, post: post) { (down) in
            if let down = down {
                down["type"] = type.rawValue
                down.saveInBackground(block: { (success, error) in
                    completion(down)
                    WDTActivity.sharedInstance().requestMyDowns(completion: { (success) in})
                })
            } else {
                let activityObj = PFObject(className: "Activity")
                activityObj["by"] = PFUser.current()
                activityObj["to"] = user
                activityObj["post"] = post
                activityObj["postText"] = post["postText"]
                activityObj["type"] = type.rawValue
                
                activityObj.saveInBackground(block: { (success, error) in
                    completion(activityObj)
                    WDTActivity.sharedInstance().requestMyDowns(completion: { (success) in})
                })
            }
        }
    }
    
    class func deleteActivity(user: PFUser, post: PFObject) {
        WDTActivity.isDown(user: user, post: post) { (down) in
            if let down = down {
                down["type"] = WDTActivityType.Undown.rawValue
                down.saveInBackground(block: { (success, error) in
                    WDTActivity.sharedInstance().requestMyDowns(completion: { (success) in})
                })
            }
        }
    }
    
    func requestMyDowns(completion: @escaping (_ success: Bool) -> Void) {
        let activitiesQuery1 = PFQuery(className: "Activity")
        activitiesQuery1.whereKey("type", equalTo: "down")
        let activitiesQuery2 = PFQuery(className: "Activity")
        activitiesQuery2.whereKey("isDowned", equalTo: true)
        
        let activitiesQuery = PFQuery.orQuery(withSubqueries: [activitiesQuery1, activitiesQuery2])
        activitiesQuery.whereKey("by", equalTo: currentUser)
        activitiesQuery.whereKey("isDowned", equalTo: true)
        activitiesQuery.includeKey("post")
        activitiesQuery.addDescendingOrder("createdAt")
        
        if let post = post {
            activitiesQuery.whereKey("post", equalTo: post)
        }
        
        activitiesQuery.findObjectsInBackground(block: { (myDowns, error) in
            if let myDowns = myDowns {
                self.myDowns = myDowns.filter({
                    if let _ = $0["post"] {
                        return true
                    } else {
                        return false
                    }
                })
                
                completion(true)
            } else {
                completion(false)
            }
        })
    }
    
    func requestDowns(completion: @escaping (_ success: Bool) -> Void) {
        let activitiesQuery1 = PFQuery(className: "Activity")
        activitiesQuery1.whereKey("type", equalTo: "down")
        let activitiesQuery2 = PFQuery(className: "Activity")
        activitiesQuery2.whereKey("isDowned", equalTo: true)
        
        let activitiesQuery = PFQuery.orQuery(withSubqueries: [activitiesQuery1, activitiesQuery2])
        activitiesQuery.whereKey("to", equalTo: currentUser)
        activitiesQuery.includeKey("post")
        activitiesQuery.includeKey("by")
        activitiesQuery.includeKey("to")
        activitiesQuery.addDescendingOrder("createdAt")
        
        if let post = post {
            activitiesQuery.whereKey("post", equalTo: post)
        }
        
        activitiesQuery.findObjectsInBackground(block: { (downs, error) in
            if let downs = downs {
                self.downs = downs.filter({
                    if let _ = $0["post"] {
                        return true
                    } else {
                        return false
                    }
                })

                completion(true)
            } else {
                completion(false)
            }
        })
    }
    
    func requestChats(completion: @escaping (_ success: Bool) -> Void) {
        let activitiesToMeQuery = PFQuery(className: "Activity")
        activitiesToMeQuery.whereKey("by", equalTo: currentUser)
        
        let activitiesFromMeQuery = PFQuery(className: "Activity")
        activitiesFromMeQuery.whereKey("to", equalTo: currentUser)
        
        let activitiesQuery = PFQuery.orQuery(withSubqueries: [activitiesToMeQuery, activitiesFromMeQuery])
        activitiesQuery.includeKey("post")
        activitiesQuery.includeKey("by")
        activitiesQuery.includeKey("to")
        activitiesQuery.includeKey("lastMessageDate")
        activitiesQuery.addDescendingOrder("lastMessageDate")
        
        activitiesQuery.findObjectsInBackground(block: { (chats, error) in
            if let chats = chats {
                
                self.chats = chats.flatMap { chat in
                    return Activity(pfObject: chat)
                }
                
                completion(true)
            } else {
                completion(false)
            }
        })
    }
}


final class Activity {

    var by: PFUser
    var to: PFUser
    var post: PFObject
    var postText: String
    var lastMessageText: String
    var lastMessageDate: Date
    var lastMessageRead: Bool
    var lastMessageUser: PFUser?
    var isDowned: Bool
//    var replies: [PFObject]
    
    fileprivate var pfObject: PFObject
    
    
    init?(pfObject: PFObject) {
        self.pfObject = pfObject
        
        if let by = pfObject["by"] as? PFUser,
            let to = pfObject["to"] as? PFUser,
            let post = pfObject["post"] as? PFObject,
            let postText = pfObject["postText"] as? String {
            
            let lastMessageText = pfObject["lastMessageText"] as? String ?? ""
            let lastMessageDate = pfObject["lastMessageDate"] as? Date ?? pfObject["replyDate"] as? Date ?? Date()
            let lastMessageRead = pfObject["lastMessageRead"] as? Bool ?? true
            let lastMessageUser = pfObject["lastMessageUser"] as? PFUser
            let isDowned = pfObject["isDowned"] as? Bool ?? false
            
            self.by = by
            self.to = to
            self.post = post
            self.postText = postText
            self.lastMessageText = lastMessageText
            self.lastMessageDate = lastMessageDate
            self.lastMessageRead = lastMessageRead
            self.lastMessageUser = lastMessageUser
            self.isDowned = isDowned
            
        } else {
            return nil
        }
    }
    
    init(by: PFUser,
         to: PFUser,
         post: PFObject,
         postText: String,
         lastMessageText: String,
         lastMessageDate: Date,
         lastMessageRead: Bool,
         lastMessageUser: PFUser,
         isDowned: Bool) {
        pfObject = PFObject(className: "Activity")
        
        self.by = by
        self.to = to
        self.post = post
        self.postText = postText
        self.lastMessageText = lastMessageText
        self.lastMessageDate = lastMessageDate
        self.lastMessageRead = lastMessageRead
        self.lastMessageUser = lastMessageUser
        self.isDowned = isDowned
    }
    
    var object: PFObject {
        pfObject["by"] = self.by
        pfObject["to"] = self.to
        pfObject["post"] = self.post
        pfObject["postText"] = self.postText
        pfObject["lastMessageText"] = self.lastMessageText
        pfObject["lastMessageDate"] = self.lastMessageDate
        pfObject["lastMessageRead"] = self.lastMessageRead
        pfObject["lastMessageUser"] = self.lastMessageUser ?? NSNull()
        pfObject["isDowned"] = self.isDowned
        
        return pfObject
    }
    
    
    func addReply(_ reply: Reply, completion: (() -> Void)?) {
        let repliesRelation = self.object.relation(forKey: "replies")
        repliesRelation.add(reply.object)
        
        self.lastMessageText = reply.photoURL != nil ? "Photo" : reply.body ?? ""
        self.lastMessageDate = reply.object.updatedAt ?? Date()
        self.lastMessageRead = false
        self.lastMessageUser = PFUser.current()
        if reply.isDown {
            self.isDowned = reply.isDown
        }
        
        self.object.saveInBackground { (_, _) in
            completion?()
        }
    }
    

}


final class Reply {

    var by: PFUser
    var to: PFUser
    var body: String?
    var photoURL: String?
    var isDown: Bool
    
    fileprivate var pfObject: PFObject
    
    
    init?(pfObject: PFObject) {
        self.pfObject = pfObject
        
        if let by = pfObject["by"] as? PFUser,
            let to = pfObject["to"] as? PFUser {
            
            let body = pfObject["body"] as? String
            let photoURL = pfObject["photoURL"] as? String
            let isDown = pfObject["isDown"] as? Bool ?? false
            
            self.by = by
            self.to = to
            self.body = body
            self.photoURL = photoURL
            self.isDown = isDown
            
        } else {
            return nil
        }
    }
    
    init(by: PFUser, to: PFUser, body: String?, photoURL: String?, isDown: Bool) {
        self.pfObject = PFObject(className: "replies")
        
        self.by = by
        self.to = to
        self.body = body
        self.photoURL = photoURL
        self.isDown = isDown
    }
    
    var object: PFObject {
        pfObject["by"] = self.by
        pfObject["to"] = self.to
        pfObject["body"] = self.body ?? NSNull()
        pfObject["photoURL"] = self.photoURL ?? NSNull()
        pfObject["isDown"] = self.isDown
        
        return pfObject
    }
    
    
    func send(completion: @escaping () -> Void) {
        self.object.saveInBackground { _ in
            completion()
        }
    }
    

}

