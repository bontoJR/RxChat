var express = require('express');
var app = express();
var http = require('http').Server(app);
var io = require('socket.io')(http);

http.listen(8000);
console.log('Server running at http://127.0.0.1:8000/');

var users = {};

app.use(express.static(__dirname + '/public'));

app.get('/api/users/online', function(req, res) {
  res.send(users);
});

app.get('/api/users/online/count', function(req, res) {
  res.json({
    numUsers: Object.keys(users).length
  });
});

io.on('connection', function(socket) {
  console.log('User with id ' + socket.id + ' has connected');
  var addedUser = false;

  socket.on('addUser', function(username) {
    console.log('Adding user: ' + username);

    addedUser = true;
    socket.username = username;
    users[username] = username;

    socket.emit('login', {
      numUsers: Object.keys(users).length
    });

    console.log('Broadcasting number of users: ' + Object.keys(users).length);
    socket.broadcast.emit('userJoined', {
      username: socket.username,
      numUsers: Object.keys(users).length
    });
  });

  socket.on('newMessage', function(msg) {
    if (!addedUser) {
      return;
    }
    console.log('Broadcasting user message: ' + msg);
    socket.broadcast.emit('newMessage', {
      username: socket.username,
      message: msg
    });
  });

  socket.on('disconnect', function() {
    if (!addedUser) {
      console.log('User with id ' + socket.id + ' has disconnected');
      return;
    }
    delete users[socket.username];
    addedUser = false;
    console.log('User ' + socket.username + ' has disconnected');

    socket.broadcast.emit('userLeft', {
      username: socket.username,
      numUsers: Object.keys(users).length
    });
  });
});
