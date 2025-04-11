import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MessagingScreen extends StatefulWidget {
  final String? contactName;
  final String? contactId;

  const MessagingScreen({super.key, this.contactName, this.contactId});

  @override
  MessagingScreenState createState() => MessagingScreenState();
}

class MessagingScreenState extends State<MessagingScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _currentChatRoomId;
  String? _currentContactName;
  String? _currentContactId;
  String? _username;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    if (widget.contactId != null && widget.contactName != null) {
      _selectContact(widget.contactId!, widget.contactName!);
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _usernameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() => _isLoading = true);
    final user = _auth.currentUser;
    if (user != null) {
      try {
        // Load private user data from 'users' collection
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        setState(() {
          _username = userDoc.data()?['username'] ?? user.email?.split('@')[0] ?? 'User';
          _isLoading = false;
        });
      } catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load user data: $e';
        });
      }
    } else {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Please sign in to continue';
      });
    }
  }

  Future<void> _setUsername() async {
    final user = _auth.currentUser;
    if (user == null || !mounted) return;

    bool shouldPop = false;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Username'),
        content: TextField(
          controller: _usernameController..text = _username ?? '',
          decoration: const InputDecoration(hintText: 'Enter your username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (_usernameController.text.trim().isNotEmpty) {
                try {
                  // Update private 'users' collection
                  await _firestore.collection('users').doc(user.uid).set(
                    {'username': _usernameController.text.trim()},
                    SetOptions(merge: true),
                  );
                  // Update public 'public_users' collection
                  await _firestore.collection('public_users').doc(user.uid).set(
                    {'username': _usernameController.text.trim()},
                    SetOptions(merge: true),
                  );
                  setState(() => _username = _usernameController.text.trim());
                  shouldPop = true;
                } catch (e) {
                  setState(() => _errorMessage = 'Failed to set username: $e');
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (shouldPop && mounted) {
      Navigator.pop(context);
    }
  }

  String _generateChatRoomId(String userId1, String userId2) {
    final ids = [userId1, userId2]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  void _selectContact(String contactId, String contactName) {
    final user = _auth.currentUser;
    if (user != null && contactId != user.uid) {
      setState(() {
        _currentContactId = contactId;
        _currentContactName = contactName;
        _currentChatRoomId = _generateChatRoomId(user.uid, contactId);
      });
      _scrollToBottom();
    } else if (contactId == user?.uid) {
      setState(() => _errorMessage = 'You cannot message yourself');
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _currentChatRoomId == null) return;

    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Please sign in to send a message');
      return;
    }

    try {
      final messageData = {
        'text': _messageController.text.trim(),
        'sender': user.uid, // Changed to 'sender' to match security rules
        'username': _username ?? 'Unknown',
        'timestamp': FieldValue.serverTimestamp(),
        'participants': [user.uid, _currentContactId],
      };

      await _firestore
          .collection('conversations')
          .doc(_currentChatRoomId)
          .collection('messages')
          .add(messageData);

      await _firestore.collection('conversations').doc(_currentChatRoomId).set({
        'participants': [user.uid, _currentContactId],
        'lastMessage': _messageController.text.trim(),
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': user.uid,
        'createdBy': user.uid,
      }, SetOptions(merge: true));

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      setState(() => _errorMessage = 'Failed to send message: $e');
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _showErrorSnackBar() {
    if (_errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage!),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Dismiss',
            onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
          ),
        ),
      );
      setState(() => _errorMessage = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) => _showErrorSnackBar());
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentContactName ?? 'Messaging'),
        backgroundColor: Colors.grey[900],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: _setUsername,
            tooltip: 'Set Username',
          ),
          IconButton(
            icon: const Icon(Icons.contacts),
            onPressed: _showContactList,
            tooltip: 'Contacts',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_currentChatRoomId == null)
                  const Expanded(
                    child: Center(
                      child: Text(
                        'Select a contact to start chatting',
                        style: TextStyle(color: Colors.white70, fontSize: 18),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[850],
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                      ),
                      child: StreamBuilder<QuerySnapshot>(
                        stream: _firestore
                            .collection('conversations')
                            .doc(_currentChatRoomId)
                            .collection('messages')
                            .orderBy('timestamp', descending: true)
                            .limit(50)
                            .snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.white)));
                          }
                          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                            return const Center(child: Text('No messages yet', style: TextStyle(color: Colors.white70)));
                          }

                          final messages = snapshot.data!.docs;
                          return ListView.builder(
                            controller: _scrollController,
                            reverse: true,
                            padding: const EdgeInsets.all(8.0),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final data = messages[index].data() as Map<String, dynamic>;
                              final isCurrentUser = data['sender'] == user?.uid; // Updated to 'sender'
                              final messageTime = (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

                              return Align(
                                alignment: isCurrentUser ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isCurrentUser ? Colors.blue[700] : Colors.grey[700],
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.2),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isCurrentUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        data['username'] ?? 'Unknown',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        data['text'] ?? '',
                                        style: const TextStyle(color: Colors.white, fontSize: 16),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${messageTime.hour}:${messageTime.minute.toString().padLeft(2, '0')}',
                                        style: const TextStyle(color: Colors.white54, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey[500]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[800],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          ),
                          style: const TextStyle(color: Colors.white),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FloatingActionButton(
                        onPressed: _sendMessage,
                        mini: true,
                        backgroundColor: Colors.blue,
                        child: const Icon(Icons.send, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  void _showContactList() {
    if (!mounted) return;
    final user = _auth.currentUser;
    if (user == null) {
      setState(() => _errorMessage = 'Please sign in to view contacts');
      return;
    }

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.grey[900],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SizedBox(
          width: double.infinity,
          height: 400,
          child: StreamBuilder<QuerySnapshot>(
            stream: _firestore.collection('public_users').snapshots(), // Updated to 'public_users'
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Error: ${snapshot.error.toString().contains('permission-denied') ? 'Permission denied. Check Firestore rules.' : snapshot.error}',
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No contacts available', style: TextStyle(color: Colors.white70)));
              }

              final currentUserId = _auth.currentUser?.uid;
              final contacts = snapshot.data!.docs.where((doc) => doc.id != currentUserId).toList();

              return ListView.builder(
                itemCount: contacts.length,
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  final contactName = contact['username'] ?? 'Unknown';
                  return ListTile(
                    title: Text(contactName, style: const TextStyle(color: Colors.white)),
                    onTap: () {
                      _selectContact(contact.id, contactName);
                      Navigator.pop(context);
                    },
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue,
                      child: Text(contactName[0].toUpperCase(), style: const TextStyle(color: Colors.white)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}