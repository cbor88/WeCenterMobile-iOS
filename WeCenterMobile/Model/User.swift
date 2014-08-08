//
//  User.swift
//  WeCenterMobile
//
//  Created by Darren Liu on 14/8/1.
//  Copyright (c) 2014年 ifLab. All rights reserved.
//

import Foundation
import CoreData

let UserModel = Model(module: "User", bundle: NSBundle.mainBundle())

class User: NSManagedObject {
    
    @NSManaged var gender: NSNumber?
    @NSManaged var birthday: NSNumber?
    @NSManaged var jobID: NSNumber?
    @NSManaged var signature: String?
    @NSManaged var agreementCount: NSNumber?
    @NSManaged var answerFavoriteCount: NSNumber?
    @NSManaged var answerCount: NSNumber?
    @NSManaged var avatarURL: String?
    @NSManaged var followerCount: NSNumber?
    @NSManaged var followingCount: NSNumber?
    @NSManaged var friendCount: NSNumber?
    @NSManaged var id: NSNumber
    @NSManaged var markCount: NSNumber?
    @NSManaged var name: String?
    @NSManaged var questionCount: NSNumber?
    @NSManaged var thankCount: NSNumber?
    @NSManaged var topicFocusCount: NSNumber?
    
    class func avatarURLWithURI(URI: String) -> String {
        return UserModel.URLStrings["Base"]! + UserModel.URLStrings["Avatar Base"]! + URI
    }
    
    class func parseUserWithProperty(user: User, property: Msr.Data.Property) {
        let data = property
        user.name = data["user_name"].asString()
        user.avatarURL = avatarURLWithURI(data["avatar_file"].asString())
        user.followerCount = data["fans_count"].asInt()
        user.friendCount = data["friend_count"].asInt()
        user.questionCount = data["question_count"].asInt()
        user.answerCount = data["answer_count"].asInt()
        user.topicFocusCount = data["topic_focus_count"].asInt()
        user.agreementCount = data["agree_count"].asInt()
        user.thankCount = data["thanks_count"].asInt()
        user.answerFavoriteCount = data["answer_favorite_count"].asInt()
        appDelegate.saveContext()
    }
    

    class func parseUserProfileWithProperty(user: User, property: Msr.Data.Property) {
        let data = property
//        println(property)
//        println(1)
//        user.name = data["user_name"].asString()
//        user.gender = data["sex"].isNull() ? 3 : data["sex"].asInt()
//        user.birthday = data["birthday"].isNull() ? 0 : data["birthday"].asInt()
//        user.jobID = data["job_id"].asInt()
//        user.signature = data["signaturn"].asString()
        appDelegate.saveContext()
    }

    
    private class func fetchUserUsingNetworkByID(id: NSNumber, success: ((User) -> Void)?, failure: ((NSError) -> Void)?) {
        UserModel.GET(UserModel.URLStrings["Information"]!,
            parameters: ["uid": id], success: {
                property in
                self.fetchUserUsingCacheByID(id,
                    success: {
                        user in
                        self.parseUserWithProperty(user, property: property)
                        user.id = id
                        appDelegate.saveContext()
                        success?(user)
                    }, failure: {
                        error in
                        let user = Model.createManagedObjectOfClass(User.self, entityName: "User") as User
                        self.parseUserWithProperty(user, property: property)
                        user.id = id
                        appDelegate.saveContext()
                        success?(user)
                    })
            }, failure: failure)
    }
    
    private class func fetchUserProfileUsingNetworkByID(id: NSNumber, success: ((User) -> Void)?, failure: ((NSError) -> Void)?) {
        UserModel.GET(UserModel.URLStrings["profile"]!,
            parameters: ["uid": id], success: {
                property in
                self.fetchUserUsingCacheByID(id,
                    success: {
                        user in
                        self.parseUserProfileWithProperty(user, property: property)
                        user.id = id
                        appDelegate.saveContext()
                        success?(user)
                    }, failure: {
                        error in
                        let user = Model.createManagedObjectOfClass(User.self, entityName: "User") as User
                        self.parseUserProfileWithProperty(user, property: property)
                        user.id = id
                        appDelegate.saveContext()
                        success?(user)
                    })
            }, failure: failure)
    }

    

    
    private class func fetchUserUsingCacheByID(id: NSNumber, success: ((User) -> Void)?, failure: ((NSError) -> Void)?) {
        let request = appDelegate.managedObjectModel.fetchRequestFromTemplateWithName("User_By_ID",
            substitutionVariables: [
                "ID": id
            ])
        var error: NSError? = nil
        let results = appDelegate.managedObjectContext.executeFetchRequest(request, error: &error) as? [User]
        if error == nil && results!.count != 0 {
            success?(results![0])
        } else {
            failure?(error != nil ? error! : NSError()) // Needs specification
        }
    }
 

    
    class func fetchUserByID(id: NSNumber, strategy: Model.Strategy, success: ((User) -> Void)?, failure: ((NSError) -> Void)?) {
        switch strategy {
        case .CacheOnly:
            fetchUserUsingCacheByID(id, success: success, failure: failure)
            break
        case .NetworkOnly:
            fetchUserUsingNetworkByID(id, success: success, failure: failure)
            fetchUserProfileUsingNetworkByID(id, success: nil  , failure: nil)
            break
        case .CacheFirst:
            fetchUserUsingCacheByID(id, success: success, failure: {
                error in
                self.fetchUserUsingNetworkByID(id, success: success, failure: failure)
                self.fetchUserProfileUsingNetworkByID(id, success: nil, failure: nil)
                })
        case .NetworkFirst:
            fetchUserUsingNetworkByID(id, success: {
                user in
                self.fetchUserProfileUsingNetworkByID(id, success: nil, failure: {
                    error in
                    self.fetchUserUsingCacheByID(id, success: success, failure: failure)
                    })
                success
                return
                }, failure: {
                error in
                self.fetchUserUsingCacheByID(id, success: success, failure: failure)
                })
        default:
            break
        }
    }
    
    class func loginWithCookieAndCacheInStorage(
        #success: ((User) -> Void)?,
        failure: ((NSError) -> Void)?) {
            let data = NSUserDefaults.standardUserDefaults().objectForKey("Cookies") as? NSData
            if data == nil {
                failure?(NSError()) // Needs specification
            } else {
                let cookies = NSKeyedUnarchiver.unarchiveObjectWithData(data) as [NSHTTPCookie]
                let storage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
                for cookie in cookies {
                    storage.setCookie(cookie)
                }
                UserModel.GET(UserModel.URLStrings["Get UID"]!,
                    parameters: nil,
                    success: {
                        property in
                        self.fetchUserByID(
                            property["uid"].asInt(),
                            strategy: .CacheFirst,
                            success: success, failure: failure)
                    }, failure: failure)
            }
    }
    
    class func loginWithName(
        name: String,
        password: String,
        success: ((User) -> Void)?,
        failure: ((NSError) -> Void)?) {
            UserModel.POST(UserModel.URLStrings["Login"]!,
                parameters: [
                    "user_name": name,
                    "password": password
                ],
                success: {
                    property in
                    let cookies = NSHTTPCookieStorage.sharedHTTPCookieStorage().cookies as [NSHTTPCookie]
                    let data = NSKeyedArchiver.archivedDataWithRootObject(cookies)
                    let defaults = NSUserDefaults.standardUserDefaults()
                    defaults.setObject(data, forKey: "Cookies")
                    defaults.synchronize()
                    self.loginWithCookieAndCacheInStorage(success: success, failure: failure)
                },
                failure: failure)
    }
    
    class func clearCookies() {
        let storage = NSHTTPCookieStorage.sharedHTTPCookieStorage()
        for cookie in storage.cookies as [NSHTTPCookie] {
            storage.deleteCookie(cookie)
        }
        NSUserDefaults.standardUserDefaults().removeObjectForKey("Cookies")
        NSUserDefaults.standardUserDefaults().synchronize()
        NSURLCache.sharedURLCache().removeAllCachedResponses()
    }
    
}
