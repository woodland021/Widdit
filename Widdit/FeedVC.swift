//
//  FeedVC.swift
//  Widdit
//
//  Created by John McCants on 3/19/16.
//  Copyright © 2016 John McCants. All rights reserved.
//

import UIKit
import Parse
import ImageViewer
import XCGLogger
import PermissionScope

protocol WDTLoad {
    func loadPosts()
}

class WDTFeed: UITableViewController, WDTLoad {
    func loadPosts() {}
}

class WDTFeedVC: UIViewController, WDTLoad {
    func loadPosts() {}
}

class FeedVC: WDTFeed {
    
    // UI Objects
    @IBOutlet weak var ivarcator: UIActivityIndicatorView!
    var refresher = UIRefreshControl()
    
    // Page Size
    var page : Int = 10
    
    var geoPoint: PFGeoPoint?
    let wdtPost = WDTPost()
    let pscope = PermissionScope()

    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        
        
        pscope.addPermission(NotificationsPermission(notificationCategories: nil),
                             message: "We use this to send you\r\nspam and love notes")
        pscope.addPermission(LocationWhileInUsePermission(),
                             message: "We use this to track\r\nwhere you live")
        
        
        pscope.show({ finished, results in
            print("got results \(results)")
            UIApplication.sharedApplication().registerForRemoteNotifications()
            self.loadPosts()
            }, cancelled: { (results) -> Void in
                print("thing was cancelled")
        })
        
        
        
        self.navigationController?.navigationBar.setBottomBorderColor()
        
        let rightBarButtonItem = UIBarButtonItem(image: UIImage(named: "ic_navbar_add"), style: .Done, target: self, action: #selector(newPostButtonTapped))
        rightBarButtonItem.tintColor = UIColor.whiteColor()
        navigationItem.rightBarButtonItem = rightBarButtonItem
        
        let queryOfAllUsers = PFUser.query()
        queryOfAllUsers?.findObjectsInBackgroundWithBlock({ (objects: [PFObject]?, error: NSError?) in
            if let objects = objects {
//
                
                let button =  UIButton(type: .Custom)
                button.setImage(UIImage(named: "ic_navbar_users"), forState: .Normal)
                button.addTarget(self, action: #selector(self.nothingToDo), forControlEvents: .TouchUpInside)
                button.frame = CGRectMake(0, 0, 53, 31)
                button.imageEdgeInsets = UIEdgeInsetsMake(-10, 12, 1, -32)//move image to the right
                let label = UILabel(frame: CGRectMake(3, 5, 50, 20))
                
                label.text = String(objects.count)
                label.textAlignment = .Left
                label.textColor = UIColor.whiteColor()
                label.backgroundColor =   UIColor.clearColor()
                button.addSubview(label)
                let barButton = UIBarButtonItem(customView: button)
                
                
                
//                let zz = UIBarButtonItem(title: , style: .Done, target: self, action: #selector())
                
            self.navigationItem.leftBarButtonItem = barButton
            }
        })
        
        
//        let shadowPath = UIBezierPath(rect: self.tabBarController!.tabBar.bounds)
//        self.tabBarController!.tabBar.layer.masksToBounds = false
//        self.tabBarController!.tabBar.layer.shadowColor = UIColor.blackColor().CGColor
//        self.tabBarController!.tabBar.layer.shadowOffset = CGSizeMake(0.0, 2.0)
//        self.tabBarController!.tabBar.layer.shadowOpacity = 0.5
//        self.tabBarController!.tabBar.layer.shadowPath = shadowPath.CGPath
//        self.tabBarController!.tabBar.layer.cornerRadius = 4.0
//        
//        
        
        configuration = ImageViewerConfiguration(imageSize: CGSize(width: 10, height: 10), closeButtonAssets: buttonAssets)
        
        // Title at the Top
        
        var logoImage:UIImage = UIImage(named: "ic_navbar_world")!
        navigationItem.titleView = UIImageView(image: logoImage)
        
        // Pull to Refresh
        refresher.addTarget(self, action: #selector(loadPosts), forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refresher)
        
        // Receive Notification from PostCell if Post is Downed, to update CollectionView
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(FeedVC.refresh), name: "downed", object: nil)

        // Receive Notification from NewPostVC
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(FeedVC.uploaded(_:)), name: "uploaded", object: nil)
    
        tableView.registerClass(FeedFooter.self, forHeaderFooterViewReuseIdentifier: "FeedFooter")
        tableView.registerClass(PostCell.self, forCellReuseIdentifier: "PostCell")
        tableView.backgroundColor = UIColor.wddSilverColor()
        tableView.rowHeight = UITableViewAutomaticDimension;
        tableView.estimatedRowHeight = 150.0;
        tableView.separatorStyle = .None
        tableView.contentInset = UIEdgeInsetsMake(-25, 0, 0, 0)

        loadPosts()
    }
    
    func newPostButtonTapped() {
        let newPostVC = NewPostVC()
        let nc = UINavigationController(rootViewController: newPostVC)
        presentViewController(nc, animated: true, completion: nil)
    }
    
    func nothingToDo() {
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    func refresh() {
        self.tableView.reloadData()
    }
    
    // reloading func with posts after received notification
    func uploaded(notification: NSNotification) {
        loadPosts()
    }
    
    override func loadPosts() {
        if PermissionScope().statusLocationInUse() == .Authorized {
            PFGeoPoint.geoPointForCurrentLocationInBackground {
                (geoPoint: PFGeoPoint?, error: NSError?) -> Void in
                
                if error == nil {
                    self.geoPoint = geoPoint
                }
            }
        }
        
        
        
        wdtPost.requestPosts { (success) in
            self.tableView.reloadData()
            self.refresher.endRefreshing()
        }
    }
    
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView.contentOffset.y >= scrollView.contentSize.height - self.view.frame.size.height * 2 {
//            loadMore()
        }
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return self.wdtPost.collectionOfPosts.count
    }
    
    // Create table view rows
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath)
        -> UITableViewCell
    {
        let cell = self.tableView!.dequeueReusableCellWithIdentifier("PostCell", forIndexPath: indexPath) as! PostCell
        let post = self.wdtPost.collectionOfPosts[indexPath.section]
        cell.moreBtn.tag = indexPath.section
        cell.moreBtn.addTarget(self, action: #selector(moreBtnTapped), forControlEvents: .TouchUpInside)
        cell.geoPoint = self.geoPoint
        cell.feed = self
        cell.fillCell(post)
        
        let postsCount = self.wdtPost.collectionOfAllPosts.filter({
            let user1 = post["user"] as! PFUser
            return user1.username == ($0["user"] as! PFUser).username
        }).count

        cell.moreBtn.hidden = postsCount == 1
        
        
        cell.setNeedsUpdateConstraints()
        cell.updateConstraintsIfNeeded()
        
        return cell
    }
    
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let indexPath = tableView.indexPathForSelectedRow
        let currentCell = tableView.cellForRowAtIndexPath(indexPath!) as! PostCell
        
        if let img = currentCell.postPhoto.image {
            
            imageProvider.image = img
            let imageViewer = ImageViewer(imageProvider: imageProvider, configuration: configuration, displacedView: currentCell.postPhoto)
            
            self.presentImageViewer(imageViewer)
        }
    }
    
    override func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        let post = self.wdtPost.collectionOfPosts[section]
        let user = post["user"] as! PFUser
        
//        if PFUser.currentUser()?.username == user.username {
//            return 0
//        } else {
            return 55
//        }
    }
    
    override func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        
        let footer = self.tableView.dequeueReusableHeaderFooterViewWithIdentifier("FeedFooter")
        let footerView = footer as! FeedFooter
        let post = self.wdtPost.collectionOfPosts[section]
        let user = post["user"] as! PFUser
        
//        if PFUser.currentUser()?.username == user.username {
//            return nil
//        } else {
            footerView.feed = self
            footerView.setDown(user, post: post)
//        }
        
        return footerView
    }
    
    
    
    
    func moreBtnTapped(sender: AnyObject) {
        let post = self.wdtPost.collectionOfPosts[sender.tag]
        let user = post["user"] as! PFUser
            let morePosts = MorePostsVC()
            morePosts.user = user
            morePosts.geoPoint = self.geoPoint
            morePosts.loadPosts()
            self.navigationController?.pushViewController(morePosts, animated: true)
    }
    
}

