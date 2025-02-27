//
//  Firebase.swift
//  pulse
//
//  Created by Rob Broadwell on 11/29/17.
//  Copyright © 2017 Rob Broadwell LTD. All rights reserved.
//

import Foundation
import Firebase
import FirebaseDatabase
import FirebaseStorage
import GeoFire

let firebase = Firebase()

class Firebase {
    
    var posts = [String : PostViewModel]()
    
    // Realtime Database
    var firebaseRef: DatabaseReference!
    var postsRef: DatabaseReference!
    var geoPostsRef: DatabaseReference!
    var usersRef: DatabaseReference!
    
    // Cloud Storage
    var storage = Storage.storage()
    var storageRef: StorageReference!
    var imagesRef: StorageReference!
    
    // Geofire
    var geoFire: GeoFire!
    var regionQuery: GFRegionQuery?
    
    init() {
        initializeRealtimeDatabase()
        initializeCloudStorage()
    }
    
    private func initializeRealtimeDatabase() {
        firebaseRef = Database.database().reference()
        postsRef = firebaseRef.child("posts")
        geoPostsRef = firebaseRef.child("geoPosts")
        usersRef = firebaseRef.child("users")
        geoFire = GeoFire(firebaseRef: geoPostsRef)
    }
    
    private func initializeCloudStorage() {
        storageRef = storage.reference()
        imagesRef = storageRef.child("images")
    }
    
    // MARK: - Update Region
    
    func update(mapRegion: MKCoordinateRegion) {
        
        if regionQuery == nil {
            
            // Update region on GeoFire query
            regionQuery = geoFire.query(with: mapRegion)
            
            // Create listener for posts entering the screen region
            regionQuery?.observe(.keyEntered, with: { (key, location) in // observer of new post objects in region
                if let key = key,
                    let location = location {
                    
                    if let hidden = UserDefaults.standard.dictionary(forKey: "hiddenPosts") {
                        if hidden[key] != nil {
                            return
                        }
                    }
                    
                    self.posts[key] = PostViewModel(key: key)
                    
                    let dict: [String : Any] = ["key": key, "location": location]
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "addPost"), object: nil, userInfo: dict)
                }
            })
            
            // Create listener for posts leaving the screen region
            regionQuery?.observe(.keyExited, with: { (key, location) in // observer of deletion of post objects in region
                if let key = key {
                    
                    self.posts.removeValue(forKey: key)
                    
                    let dict: [String : Any] = ["key": key]
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue: "removePost"), object: nil, userInfo: dict)
                }
            })
            
        } else {
            regionQuery?.region = mapRegion // update the screen region
        }
    }
    
    // MARK: - Create Post
    
    func newPost(key: String, coordinate: CLLocationCoordinate2D, image: UIImage, comment: String, time: Double) {
        
        var imageData = Data()
        imageData = UIImageJPEGRepresentation(image, 0)!
        
        uploadImage(key: key, data: imageData) { (imageURL) in
            
            self.createPost(key: key, message: comment, imageURL: imageURL, time: time)
            self.createUserPost(key: key, message: comment, imageURL: imageURL, time: time)
            self.createGeoPost(key: key, latitude: coordinate.latitude, longitude: coordinate.longitude)
            
        }
    }
    
    private func uploadImage(key: String, data: Data, completionHandler: @escaping (String) -> ()) {
        
        let thisImageRef = self.imagesRef.child(key)
        let metaData = StorageMetadata()
        metaData.contentType = "image/jpg"
        
        thisImageRef.putData(data, metadata: metaData) { metadata, error in
            if error != nil {
                print("there was an error uploading the file")
            } else {
                completionHandler(metadata!.downloadURL()!.absoluteString)
            }
        }
    }
    
    private func createPost(key: String, message: String, imageURL: String, time: Double) {
        let post = postsRef.child(key)
        post.setValue(["message": message,
                       "time": time,
                       "score": 1,
                       "image": imageURL,
                       "user": uid])
    }
    
    private func createUserPost(key: String, message: String, imageURL: String, time: Double) {
        let user = usersRef.child(uid).child("posts")
        let post = user.child(key)
        post.setValue(["message": message,
                       "time": time,
                       "score": 1,
                       "image": imageURL,
                       "user": uid])
    }
    
    private func createGeoPost(key: String, latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        geoFire.setLocation(CLLocation(latitude: latitude, longitude: longitude), forKey: key)
    }
    
}
