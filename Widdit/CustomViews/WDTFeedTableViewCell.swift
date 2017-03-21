//
//  WDTFeedTableViewCell.swift
//  Widdit
//
//  Created by JH Lee on 07/03/2017.
//  Copyright © 2017 Widdit. All rights reserved.
//

import UIKit
import ActiveLabel
import Parse
import Kingfisher
import SwiftLinkPreview

protocol WDTFeedTableViewCellDelegate {
    func onClickBtnMore(_ objPost: PFObject)
    func onTapPostPhoto(_ objPost: PFObject)
    func onClickBtnMorePosts(_ objUser: PFUser?)
    func onTapUserAvatar(_ objUser: PFUser?)
    func onUpdateObject(_ objPost: PFObject)
    func onClickBtnReply(_ objPost: PFObject)
}

class WDTFeedTableViewCell: UITableViewCell {

    @IBOutlet weak var m_imgAvatar: UIImageView!
    @IBOutlet weak var m_lblName: UILabel!
    @IBOutlet weak var m_lblExpireDate: UILabel!
    @IBOutlet weak var m_lblLocation: UILabel!
    @IBOutlet weak var m_imgPhoto: UIImageView!
    @IBOutlet weak var m_constraintPhotoHeight: NSLayoutConstraint!
    @IBOutlet weak var m_lblPhotoText: ActiveLabel!
    @IBOutlet weak var m_btnMorePost: UIButton!
    @IBOutlet weak var m_constraintBtnMorePostsHeight: NSLayoutConstraint!
    @IBOutlet weak var m_btnReply: UIButton!
    @IBOutlet weak var m_btnDown: UIButton!
    
    var m_objPost: PFObject?
    var delegate: WDTFeedTableViewCellDelegate?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
        let avatarTap = UITapGestureRecognizer(target: self, action: #selector(onTapUserAvatar))
        m_imgAvatar.addGestureRecognizer(avatarTap)
        
        let photoTap = UITapGestureRecognizer(target: self, action: #selector(onTapPhoto))
        m_imgPhoto.addGestureRecognizer(photoTap)
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    func setViewWithPFObject(_ objPost: PFObject) {
        m_objPost = objPost
        
        //User
        if let user = objPost["user"] as? PFUser {
            user.fetchIfNeededInBackground(block: { (user, error) in
                if let user = user as? PFUser {
                    if let fileAvatar = user["ava"] as? PFFile {
                        self.m_imgAvatar.kf.setImage(with: URL(string: fileAvatar.url!))
                    }
                    
                    if let userName = user["name"] as? String {
                        self.m_lblName.text = userName
                    } else {
                        self.m_lblName.text = user.username
                    }
                }
            })
        }
        
        //ExpireDate
        if let dateExpire = objPost["hoursexpired"] as? Date {
            m_lblExpireDate.text = dateExpire.timeLeft()
        }
        
        //Location
        if let _ = objPost["geoPoint"] as? PFGeoPoint {
            if let country = objPost["country"] as? String {
                m_lblLocation.text = "\(country), \(objPost["city"] as? String ?? "")"
            } else {
                m_lblLocation.text = objPost["city"] as? String ?? ""
            }
        } else {
            m_lblLocation.text = ""
        }
        
        var url: String?
        
        //Text
        if let text = objPost["postText"] as? String {
            m_lblPhotoText.text = text;
        
            //Get Urls for preview link
            let matches = WDTTextParser.getElements(from: text, with: WDTTextParser.urlPattern)
            if matches.count > 0 {
                let match = matches[0]
                let nsstring = text as NSString
                url = nsstring.substring(with: match.range)
                    .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            }
        } else {
            m_lblPhotoText.text = ""
        }
        
        //Photo
        let photo = objPost["photoUrl"] as? String ?? ""
        if photo.characters.count > 0 {
            m_imgPhoto.kf.setImage(with: URL(string: photo))
            self.m_constraintPhotoHeight.priority = 801
        } else if url != nil {
            let sl = SwiftLinkPreview()
            sl.preview(url, onSuccess: { (result) in
                if let imageUrl = result[.image] as? String {
                    objPost["photoUrl"] = imageUrl
                    objPost.saveInBackground(block: { (success, error) in
                        if let error = error {
                            print(error.localizedDescription)
                        } else {
                            self.delegate?.onUpdateObject(objPost)
                        }
                    })
                }
            }, onError: { (error) in
                print(error.description)
            })
        }

        //if user is current user, disable buttons
        m_btnReply.isEnabled = (objPost["user"] as? PFUser)?.objectId != PFUser.current()?.objectId
        m_btnDown.isEnabled = (objPost["user"] as? PFUser)?.objectId != PFUser.current()?.objectId

        //check down
        if m_btnDown.isEnabled {
            m_btnDown.isSelected = WDTActivity.sharedInstance().myDowns.filter({ (down) -> Bool in
                let localPost = down["post"] as! PFObject
                return localPost.objectId == objPost.objectId
            }).count > 0
        }
    }
    
    func setMorePosts(_ postCount: Int) {
        if postCount > 1 {
            m_btnMorePost.setTitle("+\(String(postCount - 1))", for: UIControlState.normal)
        } else {
            m_constraintBtnMorePostsHeight.constant = 0
        }
    }
    
    @IBAction func onClickBtnMore(_ sender: Any) {
        if let objPost = m_objPost {
            delegate?.onClickBtnMore(objPost)
        }
    }
    
    @IBAction func onClickBtnMorePosts(_ sender: Any) {
        if let objPost = m_objPost {
            delegate?.onClickBtnMorePosts(objPost["user"] as? PFUser)
        }
    }
    
    @IBAction func onClickBtnReply(_ sender: Any) {
        if let objPost = m_objPost {
            delegate?.onClickBtnReply(objPost)
        }
    }
    
    @IBAction func onClickBtnDown(_ sender: Any) {
        let btnDown = sender as! UIButton
        btnDown.isSelected = !btnDown.isSelected
        
        if let objPost = m_objPost {
            if btnDown.isSelected {
                WDTActivity.addActivity(user: (objPost["user"] as! PFUser), post: objPost, type: .Down, completion: { _ in })
            } else {
                WDTActivity.deleteActivity(user: (objPost["user"] as! PFUser), post: objPost)
            }
        }
    }
    
    func onTapPhoto() {
        if let objPost = m_objPost {
            delegate?.onTapPostPhoto(objPost)
        }
    }
    
    func onTapUserAvatar() {
        if let objPost = m_objPost {
            delegate?.onTapUserAvatar(objPost["user"] as? PFUser)
        }
    }
    
}
