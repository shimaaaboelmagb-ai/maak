import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

// =====================================================================
class CommunityScreen extends StatefulWidget {
  final bool isDarkMode;
  const CommunityScreen({super.key, required this.isDarkMode});

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  String userRole = 'disable';

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    if (currentUser == null) return;
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        setState(() {
          userRole =
              (userDoc.data() as Map<String, dynamic>)['role'] ?? 'disable';
        });
      }
    } catch (e) {
      debugPrint("Error checking user role: $e");
    }
  }

  Future<String?> _getUserImage(String userId) async {
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();
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
              MaterialPageRoute(
                builder: (context) =>
                    CreatePostScreen(isDarkMode: isDark, userRole: userRole),
              ),
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
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No posts yet. Be the first to share!",
                style: TextStyle(color: Colors.grey, fontSize: 16),
              ),
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
                          color: Colors.grey.withValues(alpha: 0.4),
                          size: 30,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "You've done all posts!",
                          style: TextStyle(
                            color: Colors.grey.withValues(alpha: 0.5),
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
                isDarkMode: isDark,
                userRole: userRole,
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
  final bool isDarkMode;
  final String userRole;

  const PostItemWidget({
    super.key,
    required this.postDoc,
    required this.currentUser,
    required this.getUserImageFn,
    required this.isDarkMode,
    required this.userRole,
  });

  @override
  State<PostItemWidget> createState() => _PostItemWidgetState();
}

class _PostItemWidgetState extends State<PostItemWidget> {
  Future<void> _toggleLike(String postId, List<dynamic> likedBy) async {
    if (widget.currentUser == null) return;
    DocumentReference postRef = FirebaseFirestore.instance
        .collection('posts')
        .doc(postId);

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
      builder: (context) => CommentsSheet(
        postId: postId,
        getUserImageFn: widget.getUserImageFn,
        isDarkMode: widget.isDarkMode,
        userRole: widget.userRole,
      ),
    );
  }

  Future<void> _openLocation(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;
    Color cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    Map<String, dynamic> postData =
        widget.postDoc.data() as Map<String, dynamic>;
    String postId = widget.postDoc.id;
    String authorId = postData['userId'] ?? "";
    String authorName = postData['authorName'] ?? "Unknown User";
    String text = postData['text'] ?? "";
    String? base64Image = postData['imageBase64'];
    int likesCount = postData['likesCount'] ?? 0;
    int commentsCount = postData['commentsCount'] ?? 0;
    String? locationName = postData['locationName'];
    String? locationUrl = postData['locationUrl'];
    List<dynamic> likedBy = postData['likedBy'] ?? [];
    bool isLikedByMe =
        widget.currentUser != null && likedBy.contains(widget.currentUser!.uid);

    String timeAgo = "Recently";
    if (postData['createdAt'] != null) {
      DateTime time = (postData['createdAt'] as Timestamp).toDate();
      timeAgo =
          "${time.hour}:${time.minute.toString().padLeft(2, '0')} - ${time.day}/${time.month}";
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
                      backgroundImage:
                          (profileImg != null && profileImg.isNotEmpty)
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
                    Text(
                      authorName,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: textColor,
                      ),
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.grey),
                  color: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  onSelected: (value) async {
                    if (value == 'delete' &&
                        widget.currentUser?.uid == authorId) {
                      FirebaseFirestore.instance
                          .collection('posts')
                          .doc(postId)
                          .delete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red),
                          SizedBox(width: 10),
                          Text(
                            "Delete Post",
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
            if (locationName != null && locationName.isNotEmpty) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _openLocation(locationUrl),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4A98B4).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFF4A98B4).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Color(0xFF4A98B4),
                        size: 18,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          locationName,
                          style: const TextStyle(
                            color: Color(0xFF4A98B4),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.open_in_new,
                        color: Color(0xFF4A98B4),
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (base64Image != null && base64Image.trim().isNotEmpty)
              Container(
                margin: const EdgeInsets.only(top: 15),
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Builder(
                    builder: (context) {
                      try {
                        return Image.memory(
                          base64Decode(base64Image.trim()),
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (context, error, stackTrace) {
                            return const SizedBox.shrink();
                          },
                        );
                      } catch (e) {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
              ),
            if (widget.userRole == 'helper' &&
                widget.currentUser?.uid != authorId) ...[
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4A98B4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.handshake_outlined,
                    color: Colors.white,
                  ),
                  label: const Text(
                    "Accept Help Request",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('posts')
                        .doc(postId)
                        .update({
                          'status': 'accepted',
                          'helperId': widget.currentUser?.uid,
                        });
                    if (!context.mounted) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          chatWithUser: authorName,
                          otherUserId: authorId,
                          isDarkMode: isDark,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 15),
            Divider(
              color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            ),
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
                      if (widget.currentUser?.uid == authorId) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            chatWithUser: authorName,
                            otherUserId: authorId,
                            isDarkMode: isDark,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: color == Colors.red
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
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
  final bool isDarkMode;
  final String userRole;

  const CommentsSheet({
    super.key,
    required this.postId,
    required this.getUserImageFn,
    required this.isDarkMode,
    required this.userRole,
  });

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  String? _commentLocationName;
  String? _commentLocationUrl;

  Future<void> _attachLocationToComment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectionScreen(isDarkMode: widget.isDarkMode),
      ),
    );
    if (result != null && result is Map<String, String>) {
      setState(() {
        _commentLocationName = result["name"];
        _commentLocationUrl = result["url"];
      });
    }
  }

  Future<void> _postComment() async {
    if (_commentController.text.trim().isEmpty &&
        _commentLocationName == null) {
      return;
    }
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    String authorName = user.displayName ?? "User";
    DocumentSnapshot userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    if (userDoc.exists && userDoc.data() != null) {
      authorName = userDoc.get('fullName') ?? authorName;
    }

    String commentText = _commentController.text.trim();
    _commentController.clear();

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .collection('comments')
        .add({
          'userId': user.uid,
          'authorName': authorName,
          'text': commentText,
          'locationName': _commentLocationName,
          'locationUrl': _commentLocationUrl,
          'createdAt': FieldValue.serverTimestamp(),
        });

    await FirebaseFirestore.instance
        .collection('posts')
        .doc(widget.postId)
        .update({'commentsCount': FieldValue.increment(1)});
    setState(() {
      _commentLocationName = null;
      _commentLocationUrl = null;
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
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      height: MediaQuery.of(context).size.height * 0.7,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade500,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Text(
              "Comments",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ),
          Divider(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            height: 1,
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('posts')
                  .doc(widget.postId)
                  .collection('comments')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "No comments yet.",
                      style: TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(15),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    var comment = snapshot.data!.docs[index];
                    Map<String, dynamic> commentData =
                        comment.data() as Map<String, dynamic>;
                    String commenterId = commentData['userId'] ?? "";
                    String? cLocationName = commentData['locationName'];

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
                                backgroundImage:
                                    (profileImg != null &&
                                        profileImg.isNotEmpty)
                                    ? MemoryImage(base64Decode(profileImg))
                                    : null,
                                child:
                                    (profileImg == null || profileImg.isEmpty)
                                    ? const Icon(
                                        Icons.person,
                                        color: Colors.blue,
                                        size: 15,
                                      )
                                    : null,
                              );
                            },
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: commentBg,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    commentData['authorName'] ?? "User",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  if (commentData['text'] != null)
                                    Text(
                                      commentData['text'],
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: textColor,
                                      ),
                                    ),
                                  if (cLocationName != null) ...[
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.location_on,
                                          color: Colors.orange,
                                          size: 14,
                                        ),
                                        Text(
                                          cLocationName,
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_commentLocationName != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
              color: Colors.orange.withValues(alpha: 0.1),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.orange, size: 16),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      "Attached: $_commentLocationName",
                      style: TextStyle(color: textColor, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    onPressed: () => setState(() {
                      _commentLocationName = null;
                    }),
                  ),
                ],
              ),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: sheetColor,
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black54 : Colors.grey.shade200,
                  offset: const Offset(0, -2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.pin_drop, color: Colors.orange),
                  onPressed: _attachLocationToComment,
                ),
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "Write a comment...",
                      border: InputBorder.none,
                      filled: true,
                      fillColor: commentBg,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF4A98B4)),
                  onPressed: _postComment,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
class CreatePostScreen extends StatefulWidget {
  final bool isDarkMode;
  final String userRole;
  const CreatePostScreen({
    super.key,
    required this.isDarkMode,
    required this.userRole,
  });

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final TextEditingController _postController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  String? _attachedLocationName;
  String? _attachedLocationUrl;

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

  Future<void> _attachDynamicLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapSelectionScreen(isDarkMode: widget.isDarkMode),
      ),
    );
    if (result != null && result is Map<String, String>) {
      setState(() {
        _attachedLocationName = result["name"];
        _attachedLocationUrl = result["url"];
      });
    }
  }

  Future<void> _publishPost() async {
    if (_postController.text.trim().isEmpty &&
        _selectedImage == null &&
        _attachedLocationName == null) {
      return;
    }
    setState(() {
      _isLoading = true;
    });

    try {
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      String authorName = user.displayName ?? "User";
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
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
        'locationName': _attachedLocationName,
        'locationUrl': _attachedLocationUrl,
        'createdAt': FieldValue.serverTimestamp(),
        'likesCount': 0,
        'commentsCount': 0,
        'likedBy': [],
      });

      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Publish error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
        title: const Text("Create Post"),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 15.0),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF4A98B4)),
              ),
            )
          else
            TextButton(
              onPressed: _publishPost,
              child: const Text(
                "POST",
                style: TextStyle(
                  color: Color(0xFF4A98B4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
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
                style: TextStyle(color: textColor),
                decoration: const InputDecoration(
                  hintText: "What's on your mind?",
                  border: InputBorder.none,
                ),
              ),
            ),
            if (_selectedImage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 15),
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  image: DecorationImage(
                    image: FileImage(_selectedImage!),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                    onPressed: () {
                      setState(() {
                        _selectedImage = null;
                      });
                    },
                  ),
                ),
              ),
            if (_attachedLocationName != null)
              ListTile(
                leading: const Icon(
                  Icons.location_on,
                  color: Color(0xFF4A98B4),
                ),
                title: Text(
                  _attachedLocationName!,
                  style: TextStyle(color: textColor),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() {
                    _attachedLocationName = null;
                  }),
                ),
              ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.photo_library, color: Colors.green),
                  onPressed: () => _pickImage(ImageSource.gallery),
                ),
                IconButton(
                  icon: const Icon(Icons.pin_drop, color: Colors.orange),
                  onPressed: _attachDynamicLocation,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================================================
class MapSelectionScreen extends StatefulWidget {
  final bool isDarkMode;
  const MapSelectionScreen({super.key, required this.isDarkMode});

  @override
  State<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends State<MapSelectionScreen> {
  GoogleMapController? _mapController;
  LatLng _selectedCenter = const LatLng(30.0444, 31.2357);
  String _addressName = "Click map to choose location";

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndGetLocation();
  }

  Future<void> _checkPermissionsAndGetLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }

      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
        timeLimit: const Duration(seconds: 5),
      );

      if (mounted) {
        setState(() {
          _selectedCenter = LatLng(position.latitude, position.longitude);
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_selectedCenter, 15),
        );
        _getAddressFromLatLng(_selectedCenter);
      }
    } catch (e) {
      debugPrint("Location service error: $e");
    }
  }

  Future<void> _getAddressFromLatLng(LatLng position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        Placemark place = placemarks[0];
        setState(() {
          _addressName = "${place.name ?? ''} ${place.locality ?? ''}";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addressName =
              "Selected Location (${position.latitude.toStringAsFixed(3)}, ${position.longitude.toStringAsFixed(3)})";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = widget.isDarkMode;
    Color panelColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    Color textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: panelColor,
        title: Text("Select Location", style: TextStyle(color: textColor)),
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selectedCenter,
              zoom: 14,
            ),
            onMapCreated: (controller) => _mapController = controller,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            onCameraMove: (position) => _selectedCenter = position.target,
            onCameraIdle: () => _getAddressFromLatLng(_selectedCenter),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 35),
              child: Icon(
                Icons.location_pin,
                color: Colors.red.shade700,
                size: 45,
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              color: panelColor,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _addressName,
                    style: TextStyle(color: textColor, fontSize: 14),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF4A98B4),
                      ),
                      onPressed: () {
                        String latStr = _selectedCenter.latitude.toString();
                        String lngStr = _selectedCenter.longitude.toString();
                        Navigator.pop(context, {
                          "name": _addressName,
                          "url":
                              "https://www.google.com/maps/search/?api=1&query=$latStr,$lngStr",
                        });
                      },
                      child: const Text(
                        "Confirm Location",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =====================================================================
class ChatScreen extends StatefulWidget {
  final String chatWithUser;
  final String otherUserId;
  final bool isDarkMode;
  const ChatScreen({
    super.key,
    required this.chatWithUser,
    required this.otherUserId,
    required this.isDarkMode,
  });

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
    if (currentUser != null) {
      chatRoomId = currentUser!.uid.compareTo(widget.otherUserId) > 0
          ? "${widget.otherUserId}_${currentUser!.uid}"
          : "${currentUser!.uid}_${widget.otherUserId}";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.chatWithUser)),
      body: Column(
        children: [
          Expanded(child: Container()),
          TextField(
            controller: _messageController,
            decoration: const InputDecoration(hintText: "Type message..."),
          ),
        ],
      ),
    );
  }
}
