import 'dart:io';
import 'dart:convert'; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// =====================================================================
// =====================================================================
class CommunityScreen extends StatefulWidget {
  final bool isDarkMode; // 👈 ضفنا استقبال الدارك مود هنا
  const CommunityScreen({super.key, required this.isDarkMode});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;

  Future<String?> _getUserImage(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data['profileImageBase64'];
      }
    } catch (e) {
      debugPrint("Error fetching user image: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // 🎨 ألوان الدارك مود للشاشة دي
    bool isDark = widget.isDarkMode;
    Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F9FD);
    Color appBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: isDark ? 0 : 5,
        title: Text(
          "Community",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 90.0, right: 10.0), 
        child: FloatingActionButton(
          backgroundColor: const Color(0xFF4A98B4),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => CreatePostScreen(isDarkMode: isDark)),
            );
          },
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text("No posts yet. Be the first to share!", style: TextStyle(color: Colors.grey, fontSize: 16)),
            );
          }

          return ListView.builder(
            key: const PageStorageKey('community_list_view'),
            padding: const EdgeInsets.all(15),
            itemCount: snapshot.data!.docs.length + 1, 
            itemBuilder: (context, index) {
              
              if (index == snapshot.data!.docs.length) {
                return Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 120), 
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.face_6_outlined, 
                          // ignore: deprecated_member_use
                          color: Colors.grey.withOpacity(0.4), 
                          size: 30,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "You've done all posts!",
                          style: TextStyle(
                            // ignore: deprecated_member_use
                            color: Colors.grey.withOpacity(0.5), 
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2, 
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              var postDoc = snapshot.data!.docs[index];
              return PostItemWidget(
                key: ValueKey(postDoc.id),
                postDoc: postDoc,
                currentUser: currentUser,
                getUserImageFn: _getUserImage,
                isDarkMode: isDark, // 👈 بنبعتها للكارت
              );
            },
          );
        },
      ),
    );
  }
}

// =====================================================================
class PostItemWidget extends StatefulWidget {
  final QueryDocumentSnapshot postDoc;
  final User? currentUser;
  final Future<String?> Function(String) getUserImageFn;
  final bool isDarkMode; // 👈 ضفناها هنا

  const PostItemWidget({
    super.key,
    required this.postDoc,
    required this.currentUser,
    required this.getUserImageFn,
    required this.isDarkMode,
  });

  @override
  State<PostItemWidget> createState() => _PostItemWidgetState();
}

class _PostItemWidgetState extends State<PostItemWidget> {
  
  Future<void> _toggleLike(String postId, List<dynamic> likedBy) async {
    if (widget.currentUser == null) return;

    DocumentReference postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    if (likedBy.contains(widget.currentUser!.uid)) {
      await postRef.update({
        'likedBy': FieldValue.arrayRemove([widget.currentUser!.uid]),
        'likesCount': FieldValue.increment(-1),
      });
    } else {
      await postRef.update({
        'likedBy': FieldValue.arrayUnion([widget.currentUser!.uid]),
        'likesCount': FieldValue.increment(1),
      });
    }
  }

  void _showCommentsSheet(BuildContext context, String postId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsSheet(postId: postId, getUserImageFn: widget.getUserImageFn, isDarkMode: widget.isDarkMode),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    Map<String, dynamic> postData = widget.postDoc.data() as Map<String, dynamic>;
    String postId = widget.postDoc.id; 
    
    String authorId = postData['userId'] ?? ""; 
    String authorName = postData['authorName'] ?? "Unknown User";
    String text = postData['text'] ?? "";
    String? base64Image = postData['imageBase64'];
    int likesCount = postData['likesCount'] ?? 0;
    int commentsCount = postData['commentsCount'] ?? 0;

    List<dynamic> likedBy = postData['likedBy'] ?? [];
    bool isLikedByMe = widget.currentUser != null && likedBy.contains(widget.currentUser!.uid);

    String timeAgo = "Recently";
    if (postData['createdAt'] != null) {
      DateTime time = (postData['createdAt'] as Timestamp).toDate();
      timeAgo = "${time.hour}:${time.minute.toString().padLeft(2, '0')} - ${time.day}/${time.month}";
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      color: cardColor,
      elevation: isDark ? 0 : 2,
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FutureBuilder<String?>(
                  future: widget.getUserImageFn(authorId),
                  builder: (context, snapshot) {
                    String? profileImg = snapshot.data;
                    return CircleAvatar(
                      backgroundColor: Colors.blue.shade100,
                      radius: 20,
                      backgroundImage: (profileImg != null && profileImg.isNotEmpty)
                          ? MemoryImage(base64Decode(profileImg))
                          : null,
                      child: (profileImg == null || profileImg.isEmpty)
                          ? const Icon(Icons.person, color: Colors.blue)
                          : null,
                    );
                  },
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                    Text(timeAgo, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                  ],
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  onSelected: (value) async {
                    if (value == 'delete') {
                      if (widget.currentUser != null && widget.currentUser!.uid == authorId) {
                        bool? confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: cardColor,
                            title: Text("Delete Post", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
                            content: Text("Are you sure you want to delete this post? This action cannot be undone.", style: TextStyle(color: textColor)),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false), 
                                child: const Text("Cancel", style: TextStyle(color: Colors.grey))
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                                onPressed: () => Navigator.pop(context, true), 
                                child: const Text("Delete", style: TextStyle(color: Colors.white))
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          await FirebaseFirestore.instance.collection('posts').doc(postId).delete();
                          if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted successfully!'), backgroundColor: Colors.green));
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You can only delete your own posts.'), backgroundColor: Colors.red));
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 10),
                          Text("Delete Post", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 15),

            if (text.isNotEmpty)
              Text(
                text,
                style: TextStyle(fontSize: 14, height: 1.4, color: textColor),
              ),
            
            if (base64Image != null && base64Image.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 15),
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    base64Decode(base64Image),
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),

            const SizedBox(height: 15),
            Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),

            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildInteractionButton(
                    icon: isLikedByMe ? Icons.favorite : Icons.favorite_border, 
                    color: isLikedByMe ? Colors.red : Colors.grey.shade600,
                    label: "$likesCount Likes", 
                    onTap: () => _toggleLike(postId, likedBy),
                  ),
                  _buildInteractionButton(
                    icon: Icons.comment_outlined, 
                    color: Colors.grey.shade600,
                    label: "$commentsCount Comments", 
                    onTap: () => _showCommentsSheet(context, postId),
                  ),
                  _buildInteractionButton(
                    icon: Icons.chat_bubble_outline, 
                    color: Colors.grey.shade600,
                    label: "Chat", 
                    onTap: () {
                      if (widget.currentUser != null && widget.currentUser!.uid == authorId) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("You can't chat with yourself!"), backgroundColor: Colors.orange));
                        return;
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ChatScreen(chatWithUser: authorName, otherUserId: authorId, isDarkMode: isDark)),
                      );
                    }
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionButton({required IconData icon, required Color color, required String label, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: color == Colors.red ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
class CommentsSheet extends StatefulWidget {
  final String postId;
  final Future<String?> Function(String) getUserImageFn;
  final bool isDarkMode; // 👈 ضفناها هنا

  const CommentsSheet({super.key, required this.postId, required this.getUserImageFn, required this.isDarkMode});

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String authorName = user.displayName ?? "User";
    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    if (userDoc.exists && userDoc.data() != null) authorName = userDoc.get('fullName') ?? authorName;

    String commentText = _commentController.text.trim();
    _commentController.clear(); 

    await FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').add({
      'userId': user.uid,
      'authorName': authorName,
      'text': commentText,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('posts').doc(widget.postId).update({
      'commentsCount': FieldValue.increment(1),
    });
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;
    Color sheetColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;
    Color commentBg = isDark ? const Color(0xFF2C2C2C) : Colors.grey.shade100;

    return Container(
      decoration: BoxDecoration(
        color: sheetColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom), 
      height: MediaQuery.of(context).size.height * 0.7, 
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey.shade500, borderRadius: BorderRadius.circular(10))),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text("Comments", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          ),
          Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, height: 1),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('posts').doc(widget.postId).collection('comments').orderBy('createdAt', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Text("No comments yet.", style: TextStyle(color: Colors.grey)));

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var comment = snapshot.data!.docs[index];
                    String commenterId = comment['userId'] ?? "";

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          FutureBuilder<String?>(
                            future: widget.getUserImageFn(commenterId),
                            builder: (context, imgSnapshot) {
                              String? profileImg = imgSnapshot.data;
                              return CircleAvatar(
                                radius: 15,
                                backgroundColor: Colors.blue.shade50,
                                backgroundImage: (profileImg != null && profileImg.isNotEmpty)
                                    ? MemoryImage(base64Decode(profileImg))
                                    : null,
                                child: (profileImg == null || profileImg.isEmpty)
                                    ? const Icon(Icons.person, color: Color.fromARGB(255, 33, 173, 243), size: 15)
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: commentBg, borderRadius: BorderRadius.circular(15)),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(comment['authorName'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                                  const SizedBox(height: 3),
                                  Text(comment['text'], style: TextStyle(fontSize: 14, color: textColor)),
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: sheetColor, boxShadow: [BoxShadow(color: isDark ? Colors.black54 : Colors.grey.shade200, offset: const Offset(0, -2), blurRadius: 5)]),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      filled: true, fillColor: commentBg, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                IconButton(icon: const Icon(Icons.send, color: Color(0xFF4A98B4)), onPressed: _postComment),
              ],
            ),
          )
        ],
      ),
    );
  }
}

// =====================================================================
class CreatePostScreen extends StatefulWidget {
  final bool isDarkMode; // 👈 ضفناها هنا
  const CreatePostScreen({super.key, required this.isDarkMode});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _postController = TextEditingController();
  File? _selectedImage; 
  bool _isLoading = false; 

  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: source, 
      imageQuality: 30, 
      maxWidth: 600,    
    );

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
      });
    }
  }

  Future<void> _publishPost() async {
    if (_postController.text.trim().isEmpty && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please write something or select an image!'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _isLoading = true; });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      String authorName = user.displayName ?? "User";
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        authorName = userDoc.get('fullName') ?? authorName;
      }

      String? base64Image;
      
      if (_selectedImage != null) {
        List<int> imageBytes = await _selectedImage!.readAsBytes();
        base64Image = base64Encode(imageBytes); 
      }

      await FirebaseFirestore.instance.collection('posts').add({
        'userId': user.uid,
        'authorName': authorName,
        'text': _postController.text.trim(),
        'imageBase64': base64Image, 
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'likedBy': [], 
      });

      if (!mounted) return;
      setState(() { _isLoading = false; });
      Navigator.pop(context); 
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post published successfully!'), backgroundColor: Colors.green));

    } catch (e) {
      if (!mounted) return;
      setState(() { _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;
    Color bgColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: bgColor,
        elevation: 0,
        leading: IconButton(icon: Icon(Icons.close, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Text("Create Post", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _publishPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A98B4),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 0,
              ),
              child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("POST", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Expanded(
              child: TextField(
                controller: _postController,
                maxLines: null, 
                keyboardType: TextInputType.multiline,
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  hintText: "What do you want to share with the community?",
                  hintStyle: TextStyle(color: Colors.grey, fontSize: 18),
                  border: InputBorder.none,
                ),
              ),
            ),
            
            if (_selectedImage != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Container(
                    width: double.infinity, height: 200, margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      image: DecorationImage(image: FileImage(_selectedImage!), fit: BoxFit.cover),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white, size: 30),
                    onPressed: () { setState(() { _selectedImage = null; }); },
                  )
                ],
              ),
              
            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200))),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.photo_library, color: Colors.green, size: 28), onPressed: () => _pickImage(ImageSource.gallery)),
                  IconButton(icon: const Icon(Icons.camera_alt, color: Colors.blue, size: 28), onPressed: () => _pickImage(ImageSource.camera)),
                  const Spacer(),
                  const Text("Add an image", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// =====================================================================
class ChatScreen extends StatefulWidget {
  final String chatWithUser; 
  final String otherUserId; 
  final bool isDarkMode; // 👈 ضفناها هنا
  
  const ChatScreen({super.key, required this.chatWithUser, required this.otherUserId, required this.isDarkMode});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  late String chatRoomId;

  @override
  void initState() {
    super.initState();
    chatRoomId = _getChatRoomId(currentUser!.uid, widget.otherUserId);
  }

  String _getChatRoomId(String a, String b) {
    if (a.compareTo(b) > 0) return "${b}_$a";
    return "${a}_$b";
  }

  Future<String?> _getChatUserImage() async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(widget.otherUserId).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        return data['profileImageBase64'];
      }
    } catch (e) {
      debugPrint("Error fetching chat user image: $e");
    }
    return null;
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || currentUser == null) return;
    
    String message = _messageController.text.trim();
    _messageController.clear();

    await FirebaseFirestore.instance
        .collection('chatRooms')
        .doc(chatRoomId)
        .collection('messages')
        .add({
      'senderId': currentUser!.uid,
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;
    Color bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F9FD);
    Color appBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;
    
    Color bubbleOther = isDark ? const Color(0xFF2C2C2C) : Colors.white;
    Color inputBg = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF2F2F2);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 1,
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: textColor), onPressed: () => Navigator.pop(context)),
        title: Row(
          children: [
            FutureBuilder<String?>(
              future: _getChatUserImage(),
              builder: (context, snapshot) {
                String? profileImg = snapshot.data;
                return CircleAvatar(
                  backgroundColor: Colors.blue.shade100,
                  radius: 18,
                  backgroundImage: (profileImg != null && profileImg.isNotEmpty)
                      ? MemoryImage(base64Decode(profileImg))
                      : null,
                  child: (profileImg == null || profileImg.isEmpty)
                      ? const Icon(Icons.person, color: Colors.blue, size: 20)
                      : null,
                );
              },
            ),
            const SizedBox(width: 10),
            Text(widget.chatWithUser, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('chatRooms')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true) 
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text("Say hi to ${widget.chatWithUser}! 👋", style: const TextStyle(color: Colors.grey, fontSize: 16)));
                }

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true, 
                  padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var msg = messages[index];
                    bool isMe = msg['senderId'] == currentUser?.uid; 

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF4A98B4) : bubbleOther,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(15),
                            topRight: const Radius.circular(15),
                            bottomLeft: Radius.circular(isMe ? 15 : 0), 
                            bottomRight: Radius.circular(isMe ? 0 : 15), 
                          ),
                          boxShadow: [BoxShadow(color: isDark ? Colors.black26 : Colors.grey.shade200, blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Text(
                          msg['text'],
                          style: TextStyle(color: isMe ? Colors.white : textColor, fontSize: 15),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(color: appBarColor, boxShadow: [BoxShadow(color: isDark ? Colors.black54 : Colors.grey.shade200, offset: const Offset(0, -2), blurRadius: 5)]),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.add_photo_alternate_outlined, color: Colors.grey), onPressed: () {}),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Type a message...", hintStyle: TextStyle(color: Colors.grey.shade500),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                      filled: true, fillColor: inputBg, contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF4A98B4), radius: 22,
                  child: IconButton(icon: const Icon(Icons.send, color: Colors.white, size: 20), onPressed: _sendMessage),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}