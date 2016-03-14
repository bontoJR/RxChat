//
//  ViewController.swift
//  RxChat
//
//  Created by Junior B. on 13/03/16.
//  Copyright © 2016 Sideeffects.xyz. All rights reserved.
//

import UIKit
import SocketIOClientSwift
import RxSwift
import JSQMessagesViewController

class ViewController: JSQMessagesViewController, UIAlertViewDelegate {
    
    private var user = BehaviorSubject(value: "")
    private var messages: [JSQMessage] = []
    
    private let socket = SocketIOClient(socketURL: NSURL(string: "http://localhost:8000")!, options: [.Log(true), .ForcePolling(true)])
    private let disposeBag = DisposeBag()
    
    private let incomingBubble = JSQMessagesBubbleImageFactory().incomingMessagesBubbleImageWithColor(UIColor(red: 10/255, green: 180/255, blue: 230/255, alpha: 1.0))
    private let outgoingBubble = JSQMessagesBubbleImageFactory().outgoingMessagesBubbleImageWithColor(UIColor.lightGrayColor())

    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        self.setup()
        
        user
            .distinctUntilChanged()
            .subscribeNext() { username in
                self.senderId = username
                self.senderDisplayName = username
                self.socket.emit("addUser", withItems:[username])
            }.addDisposableTo(disposeBag)
        
        socket.rx_event
            .filter({ $0.event == "connect"})
            .map({ _ in return () })
            .subscribeNext { _ in
                self.title = "RxChat (Connected)"
            }.addDisposableTo(disposeBag)
        
        socket.rx_event
            .filter({ $0.event == "login" && $0.items?.count > 0})
            .map({ Array($0.items!) })
            .subscribeNext { login in
                let users = login[0]["numUsers"] ?? 0
                let messageContent = "Welcome, users online \(users!)"
                let message = JSQMessage(senderId: "System", displayName: "System", text: messageContent)
                self.messages += [message]
                self.finishReceivingMessage()
            }.addDisposableTo(disposeBag)
        
        socket.rx_event
            .filter({ $0.event == "newMessage" && $0.items?.count > 0})
            .map({ Array($0.items!) })
            .subscribeNext { data in
                let username = data[0]["username"] as? String ?? "unknown"
                let text = data[0]["message"] as? String ?? "invalid text"
                let message = JSQMessage(senderId: username, displayName: username, text: text)
                self.messages += [message]
                self.finishSendingMessage()
            }.addDisposableTo(disposeBag)
        
        socket.rx_event
            .filter({ $0.event == "userJoined" && $0.items?.count > 0})
            .map({ $0.items![0]["username"].map({ "User joined: \($0)"})})
            .subscribeNext { text in
                let message = JSQMessage(senderId: "System", displayName: "System", text: text)
                self.messages += [message]
                self.finishReceivingMessage()
            }.addDisposableTo(disposeBag)
        
        socket.rx_event
            .filter({ $0.event == "userLeft" && $0.items?.count > 0})
            .map({ $0.items![0]["username"].map({ "User left: \($0)"})})
            .subscribeNext { text in
                let message = JSQMessage(senderId: "System", displayName: "System", text: text)
                self.messages += [message]
                self.finishReceivingMessage()
            }.addDisposableTo(disposeBag)
        
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidAppear(animated)
        
        displayUsernameAlert()
        socket.connect()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: Convenience
    
    func reloadMessagesView() {
        self.collectionView?.reloadData()
    }

    // JSQMessagesCollectionViewDataSource
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.messages.count
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData! {
        let data = self.messages[indexPath.row]
        return data
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didDeleteMessageAtIndexPath indexPath: NSIndexPath!) {
        self.messages.removeAtIndex(indexPath.row)
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource! {
        let data = messages[indexPath.row]
        switch(data.senderId) {
        case self.senderId:
            return self.outgoingBubble
        default:
            return self.incomingBubble
        }
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    
    // MARK: Toolbar
    
    override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: NSDate!) {
        let message = JSQMessage(senderId: senderId, senderDisplayName: senderDisplayName, date: date, text: text)
        self.messages += [message]
        self.finishSendingMessage()
        self.socket.emit("newMessage", [text])
    }
    
    override func didPressAccessoryButton(sender: UIButton!) {
        
    }
    
    // MARK: Alert View
    func displayUsernameAlert() {
        let alertController = UIAlertController(title: "Login", message: "Please enter your username", preferredStyle: UIAlertControllerStyle.Alert)
        alertController.addTextFieldWithConfigurationHandler() { textField in
            textField.placeholder = "Username"
        }
        
        let okAction = UIAlertAction(title: "OK", style: UIAlertActionStyle.Default) { _ in
            let usernameTextfield = alertController.textFields![0] as UITextField
            guard let username = usernameTextfield.text where username != "" else {
                self.displayUsernameAlert()
                return
            }
            
            self.user.onNext(username)
        }
        
        alertController.addAction(okAction)
        
        presentViewController(alertController, animated: true, completion: nil)
    }

    
    func setup() {
        self.senderId = ""
        self.senderDisplayName = ""
    }
    
    
}

