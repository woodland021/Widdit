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

class WDTImageProvider: ImageProvider {
    
    var image: UIImage = UIImage()
    
    func provideImage(completion: UIImage? -> Void) {
        completion(image)
    }
    
    func provideImage(atIndex index: Int, completion: UIImage? -> Void) {
        completion(image)
    }
}

class FeedVC: UITableViewController {
    
    // UI Objects
    @IBOutlet weak var collectionViewFlowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var indicator: UIActivityIndicatorView!
    var refresher = UIRefreshControl()
    
    var collectionOfPosts = [PFObject]()
    var collectionOfAllPosts = [PFObject]()

    // Page Size
    var page : Int = 10
    
    var geoPoint: PFGeoPoint?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Title at the Top
        self.navigationItem.title = "The World"
        
        // Pull to Refresh
        refresher.addTarget(self, action: #selector(loadPosts), forControlEvents: UIControlEvents.ValueChanged)
        self.tableView.addSubview(refresher)
        
        // Receive Notification from PostCell if Post is Downed, to update CollectionView
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(FeedVC.refresh), name: "downed", object: nil)

        // Receive Notification from NewPostVC
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(FeedVC.uploaded(_:)), name: "uploaded", object: nil)
    
        self.tableView.registerClass(PostCell2.self, forCellReuseIdentifier: "PostCell")
        self.tableView.backgroundColor = UIColor.whiteColor()
        self.tableView.rowHeight = UITableViewAutomaticDimension;
        self.tableView.estimatedRowHeight = 150.0;
        self.tableView.separatorStyle = .None

        
        self.loadPosts()
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
    
    func loadPosts() {
        PFGeoPoint.geoPointForCurrentLocationInBackground {
            (geoPoint: PFGeoPoint?, error: NSError?) -> Void in
            
            if error == nil {
                self.geoPoint = geoPoint
            }
        }
        
        let query = PFQuery(className: "posts")
        query.limit = self.page
        query.addDescendingOrder("createdAt")
        query.includeKey("user")
        query.whereKeyExists("user")
        query.findObjectsInBackgroundWithBlock({ (posts: [PFObject]?, error: NSError?) -> Void in
            if error == nil {
                if let posts = posts {
                    self.collectionOfAllPosts = posts
                    
                    self.collectionOfAllPosts = self.collectionOfAllPosts.filter({
                        let parseDate = $0.objectForKey("hoursexpired") as! NSDate
                        if NSDate().timeIntervalSince1970 >= parseDate.timeIntervalSince1970 {
                            let delete = PFObject(withoutDataWithClassName: "posts", objectId: $0.objectId)
                            delete.deleteInBackgroundWithBlock({ (success, err) in
                                if success {
                                    print("Successfully deleted expired post")
                                    dispatch_async(dispatch_get_main_queue(), {
                                        
                                    })
                                } else {
                                    print("Failed to delete expired post: \(err)")
                                }
                            })
                            return false
                        } else {
                            return true
                        }
                    })
                    
                    self.collectionOfPosts = self.collectionOfAllPosts.reduce([], combine: { (acc: [PFObject], current: PFObject) -> [PFObject] in
                        if acc.contains( {
                            if $0["user"].objectId == current["user"].objectId {
                                return true
                            } else {
                                return false
                            }
                        }) {
                            return acc
                        } else {
                            let allPostsOfUser = self.collectionOfAllPosts.filter({$0["user"].objectId == current["user"].objectId
                            })
                            if let newest = allPostsOfUser.first {
                                return acc + [newest]
                            } else {
                                return acc
                            }
                        }
                    })
                }
            }
            
            
            
            
            self.tableView.reloadData()
            self.refresher.endRefreshing()
            
        })
    }
    
    override func scrollViewDidScroll(scrollView: UIScrollView) {
        if scrollView.contentOffset.y >= scrollView.contentSize.height - self.view.frame.size.height * 2 {
//            loadMore()
        }
    }

    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
      if segue.identifier == "segueToMorePosts" {
        let destVC = segue.destinationViewController as! UserMorePostsViewController
        let i = sender?.layer.valueForKey("index") as! NSIndexPath
        let post = self.collectionOfPosts[i.row]
        let user = post["user"] as! PFUser
        destVC.currentUser = user.username
    }
    }

    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.collectionOfPosts.count
    }
    
    // Create table view rows
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath)
        -> UITableViewCell
    {
        let cell = self.tableView!.dequeueReusableCellWithIdentifier("PostCell", forIndexPath: indexPath) as! PostCell2
        
        let post = self.collectionOfPosts[indexPath.row]
        let user = post["user"] as! PFUser
        
        cell.selectionStyle = .None
        
        let username = user.username
        cell.userNameBtn.setTitle(username, forState: .Normal)
        cell.post = post
        cell.user = user
        
        if self.collectionOfPosts.count == 0 {
            cell.postText.text = "Awaiting first post..."
            cell.userNameBtn.setTitle("Admin", forState: .Normal)
            cell.firstNameLbl.text = "Admin"
            cell.imDownBtn.hidden = true
            cell.replyBtn.hidden = true
            cell.userNameBtn.hidden = true
            cell.moreBtn.hidden = true
        } else {
            cell.userNameBtn.tag = indexPath.row
            cell.replyBtn.tag = indexPath.row
            cell.replyBtn.addTarget(self, action: #selector(replyBtnTapped), forControlEvents: .TouchUpInside)
            cell.moreBtn.addTarget(self, action: #selector(moreBtnTapped), forControlEvents: .TouchUpInside)
//            let tapGestureRecognizer = UITapGestureRecognizer(target:self, action:#selector(FeedVC.imageTapped(_:)))
//            cell.postPhoto.userInteractionEnabled = true
//            cell.postPhoto.addGestureRecognizer(tapGestureRecognizer)
            
            
            cell.postText.text = post["postText"] as! String
            cell.firstNameLbl.text = user["firstName"] as? String
            cell.imDownBtn.hidden = false
            cell.userNameBtn.hidden = false
            cell.moreBtn.hidden = false
            
            if PFUser.currentUser()?.username == user.username {
                cell.replyBtn.hidden = true
                cell.imDownBtn.hidden = true
                cell.myPost = true
            } else {
                cell.replyBtn.hidden = false
                cell.imDownBtn.hidden = false
                cell.myPost = false
            }
            
        }

        // manipulate down button depending on did user like it or not
        let didDown = PFQuery(className: "downs")
        didDown.whereKey("by", equalTo: PFUser.currentUser()!.username!)
        didDown.whereKey("to", equalTo: user.username!)
        didDown.whereKey("post", equalTo: post)
        didDown.countObjectsInBackgroundWithBlock { (count:Int32, error:NSError?) -> Void in
            // if no any likes are found, else found likes
            if count == 0 {
                cell.imDownBtn.setTitle("I'm Down", forState: .Normal)
            } else {
                cell.imDownBtn.setTitle("Undown", forState: .Normal)
            }
        }
        
        // Place Profile Picture
        user["ava"].getDataInBackgroundWithBlock { (data: NSData?, error: NSError?) -> Void in
            cell.avaImage.image = UIImage(data: data!)
        }
        
        
        if let photoFile = post["photoFile"] {
            cell.postPhoto.image = UIImage()
            
            photoFile.getDataInBackgroundWithBlock { (data: NSData?, error: NSError?) -> Void in
                cell.postPhoto.image = UIImage(data: data!)
            }
        } else {
            cell.postPhoto.image = nil
        }
        
        let hoursexpired = post["hoursexpired"] as! NSDate
        let timeLeft = hoursexpired.timeIntervalSince1970 - NSDate().timeIntervalSince1970
        
        cell.timeLbl.text = NSDateComponentsFormatter.wdtLeftTime(Int(timeLeft)) + " left"
        
        if let postGeoPoint = post["geoPoint"] {
            print(self.geoPoint)
            
            cell.distanceLbl.text = String(format: "%.1f mi", postGeoPoint.distanceInMilesTo(self.geoPoint))
        } else {
            cell.distanceLbl.text = ""
        }
        
        
        cell.setNeedsUpdateConstraints()
        cell.updateConstraintsIfNeeded()
        
        return cell
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let indexPath = tableView.indexPathForSelectedRow
        let currentCell = tableView.cellForRowAtIndexPath(indexPath!) as! PostCell2
        
        if let img = currentCell.postPhoto.image {
            let imageProvider = WDTImageProvider()
            imageProvider.image = img
            let buttonAssets = CloseButtonAssets(normal: UIImage(named:"DeletePhotoButton")!, highlighted: UIImage(named: "DeletePhotoButton"))
            let configuration = ImageViewerConfiguration(imageSize: CGSize(width: 10, height: 10), closeButtonAssets: buttonAssets)
            
            let imageViewer = ImageViewer(imageProvider: imageProvider, configuration: configuration, displacedView: currentCell.postPhoto)
            self.presentImageViewer(imageViewer)
        }
    }
    
    func replyBtnTapped(sender: AnyObject) {
        let destVC = ReplyViewController()
        let post = self.collectionOfPosts[sender.tag]
        destVC.recipient = post.objectForKey("user") as! PFUser
        destVC.usersPost = post
        self.navigationController?.pushViewController(destVC, animated: true)
    }
    
    func moreBtnTapped(sender: AnyObject) {
        // If user tapped on himself go home, else go to guest
        let post = self.collectionOfPosts[sender.tag]
        let user = post["user"] as! PFUser
//        if user.username == PFUser.currentUser()?.username {
//            let home = self.storyboard?.instantiateViewControllerWithIdentifier("HomeVC") as! HomeVC
//            self.navigationController?.pushViewController(home, animated: true)
//        } else {
            let guest = GuestVC()
            guest.user = user
            guest.geoPoint = self.geoPoint
            guest.collectionOfPosts = self.collectionOfAllPosts.filter({
                let u = $0["user"] as! PFUser
                if u.username == user.username {
                    return true
                } else {
                    return false
                }
            })
            self.navigationController?.pushViewController(guest, animated: true)
//        }
    }
    
    // alert action
    func alert (title: String, message : String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
        let ok = UIAlertAction(title: "OK", style: .Cancel, handler: nil)
        alert.addAction(ok)
        presentViewController(alert, animated: true, completion: nil)
    }

    @IBAction func openSlack(sender: UIButton) {

    }

   
}

extension Array where Element: Equatable {

  public func uniq() -> [Element] {
    var arrayCopy = self
    arrayCopy.uniqInPlace()
    return arrayCopy
  }

  mutating public func uniqInPlace() {
    var seen = [Element]()
    var index = 0
    for element in self {
      if seen.contains(element) {
        removeAtIndex(index)
        print(seen.count)
      } else {
        seen.append(element)
        index += 1
      }
    }
  }
}
