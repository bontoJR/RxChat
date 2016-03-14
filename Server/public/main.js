var username = prompt("What is your name", "Type you name here");

$(function() {
  var FADE_TIME = 150; // ms
  var COLORS = [
    '#FF5600', '#339864', '#AA7C39', '#C64300',
    '#339900', '#11C164', '#33B039', '#9B5D00',
    '#0D58A6', '#094481', '#00AA72', '#006746'
  ];

  var $window = $(window);
  var $messages = $('.messages'); // Messages area
  var $inputMessage = $('.inputMessage'); // Input message input box

  var connected = false;

  var socket = io();

  socket.emit('addUser', username);
  $currentInput = $inputMessage.focus();

  // wrap Socket.io in RX
  // ref: https://github.com/Reactive-Extensions/RxJS/issues/112
  var rxEvent = Rx.Observable.create (function (obs) {
      // Handle messages
      socket.io.on('packet', function (packet) {
          if (packet.data) obs.onNext({
              name: packet.data[0],
              data: packet.data[1]
          });
      });
      socket.on('error', function (err) { obs.onError(err); });
      socket.on('reconnect_error', function (err) { obs.onError(err); });
      socket.on('reconnect_failed', function () { obs.onError(new Error('reconnection failed')); });
      socket.io.on('close', function () { obs.onCompleted(); });

      // Return way to unsubscribe
      return function() {
          socket.close();
      };
  });

  function addParticipantsMessage (data) {
    var message = '';
    if (data.numUsers === 1) {
      message += "there's 1 participant";
    } else {
      message += "there're " + data.numUsers + " participants";
    }
    addChatMessage({
        username: "System",
        message: message
    });
  }

  function sendMessage () {
    var message = $inputMessage.val();
    message = cleanInput(message);
    if (message && connected) {
      $inputMessage.val('');
      addChatMessage({
        username: username,
        message: message
      });
      socket.emit('newMessage', message);
    }
  }

  function addChatMessage (data, options) {

    var $usernameDiv = $('<span class="username"/>')
      .text(data.username)
      .css('color', getUsernameColor(data.username));
    var $messageBodyDiv = $('<span class="messageBody">')
      .text(data.message);

    var $messageDiv = $('<li class="message"/>')
      .data('username', data.username)
      .append($usernameDiv, $messageBodyDiv);

    addMessageElement($messageDiv, options);
  }

  function addMessageElement (el, options) {
    var $el = $(el);

    // Setup default options
    if (!options) {
      options = {};
    }
    if (typeof options.fade === 'undefined') {
      options.fade = true;
    }
    if (typeof options.prepend === 'undefined') {
      options.prepend = false;
    }

    // Apply options
    if (options.fade) {
      $el.hide().fadeIn(FADE_TIME);
    }
    if (options.prepend) {
      $messages.prepend($el);
    } else {
      $messages.append($el);
    }
    $messages[0].scrollTop = $messages[0].scrollHeight;
  }

  // Prevents input from having injected markup
  function cleanInput (input) {
    return $('<div/>').text(input).text();
  }


  // Gets the color of a username through our hash function
  function getUsernameColor (username) {
    // Compute hash code
    var hash = 7;
    for (var i = 0; i < username.length; i++) {
       hash = username.charCodeAt(i) + (hash << 5) - hash;
    }
    // Calculate color
    var index = Math.abs(hash % COLORS.length);
    return COLORS[index];
  }

  // Keyboard events

  $window.keydown(function (event) {
    // Auto-focus the current input when a key is typed
    if (!(event.ctrlKey || event.metaKey || event.altKey)) {
      $currentInput.focus();
    }
    // When the client hits ENTER on their keyboard
    if (event.which === 13) {
      if (username) {
        sendMessage();
      } else {
        setUsername();
      }
    }
  });


  // Focus input when clicking on the message input's border
  $inputMessage.click(function () {
    $inputMessage.focus();
  });

  // Socket events

  rxEvent
    .filter(function(data) { return data.name === "login"; })
    .map(function(data) { return data.data; })
    .subscribe(function(loginData){
      connected = true;
      addChatMessage({username: "System", message: "Welcome"});
      addParticipantsMessage(loginData);
    });

  rxEvent
    .filter(function(data) { return data.name === "newMessage"; })
    .map(function(data) { return data.data; })
    .subscribe(function(messageData){
      addChatMessage(messageData);
    });

  rxEvent
    .filter(function(data) { return data.name === "userJoined"; })
    .map(function(data) { return data.data; })
    .subscribe(function(userData) {
      addChatMessage({ username: "System", message: userData.username + ' joined' });
      addParticipantsMessage(userData);
    });

  rxEvent
    .filter(function(data) { return data.name === "userLeft"; })
    .map(function(data) { return data.data; })
    .subscribe(function(userData) {
      addChatMessage({ username: "System", message: userData.username + ' left' });
      addParticipantsMessage(userData);
    });

});
