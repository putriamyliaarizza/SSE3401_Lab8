import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path/path.dart' as path;
import 'package:image_picker/image_picker.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({Key? key}) : super(key: key);

  @override
  _DashboardState createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  FirebaseStorage storage = FirebaseStorage.instance;
  late CollectionReference imgRef;
  String _locationMessage = "";
  String _uploadTime = "";
  String _userDescription = "";
  final _descriptionController = TextEditingController();

  // Determine location on upload
  void _getCurrentLocation() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
    print(position);

    setState(() {
      _locationMessage = "${position.latitude}, ${position.longitude}";
      _uploadTime = DateTime.now().toString();
    });
  }

  // Select a photo from the gallery or camera to upload
  Future<void> _upload(String uploadType) async {
    final picker = ImagePicker();
    PickedFile? pickedImage;
    try {
      pickedImage = await picker.getImage(
        source: uploadType == 'camera'
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 1920,
      );

      final String fileName = path.basename(pickedImage!.path);
      File imageFile = File(pickedImage.path);

      _getCurrentLocation();

      try {
        // Upload the selected photo with some custom metadata
        final uploadTask = storage
            .ref()
            .child('Gallery/${fileName}')
            .putFile(
              imageFile,
              SettableMetadata(
                customMetadata: {
                  'description': 'New Image',
                  'location': _locationMessage,
                  'dateTime': _uploadTime,
                },
              ),
            );

        await uploadTask.whenComplete(() async {
          final imageUrl = await uploadTask.snapshot.ref.getDownloadURL();
          imgRef.add({
            'url': imageUrl,
            'description': 'New Image',
            'location': _locationMessage,
            'dateTime': _uploadTime,
          });
        });

        // Refresh the UI
        setState(() {});
      } on FirebaseException catch (error) {
        print(error);
        if (error.code == 'object-not-found') {
          print('File does not exist at the specified reference');
          // Handle the case where the file doesn't exist
        } else {
          // Handle other types of exceptions
          print('Error uploading file: $error');
        }
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    super.initState();
    imgRef = FirebaseFirestore.instance.collection('Posts');
  }

  // Retrieve the uploaded images
  Future<List<Map<String, dynamic>>> _loadImages() async {
    List<Map<String, dynamic>> files = [];

    try {
      final ListResult result = await storage.ref().child('Gallery').listAll();
      final List<Reference> allFiles = result.items;

      if (allFiles.isEmpty) {
        print('Gallery folder is empty');
        // Handle the case where the 'Gallery' folder is empty
      }

      await Future.forEach<Reference>(allFiles, (file) async {
        try {
          final String fileUrl = await file.getDownloadURL();
          final FullMetadata fileMeta = await file.getMetadata();
          files.add({
            "url": fileUrl,
            "path": file.fullPath,
            "description": fileMeta.customMetadata!['description'],
            "location": _locationMessage,
            "dateTime": _uploadTime
          });
        } catch (error) {
          if (error is FirebaseException && error.code == 'object-not-found') {
            print('File does not exist at the specified reference');
            // Handle the case where the file doesn't exist
          } else {
            // Handle other types of exceptions
            print('Error loading file: $error');
          }
        }
      });
    } catch (e) {
      print('Error loading images: $e');
      // Handle the error, such as displaying an error message or taking other actions
    }

    return files;
  }

  // Delete the selected image
  Future<void> _delete(String ref) async {
    try {
      await storage.ref(ref).delete();
      // Rebuild the UI
      setState(() {});
    } catch (e) {
      if (e is FirebaseException && e.code == 'object-not-found') {
        print('File does not exist at the specified reference');
        // Handle the case where the file doesn't exist
      } else {
        // Handle other types of exceptions
        print('Error deleting file: $e');
      }
    }
  }

  // Edit description
  Future<void> _setDescription(String ref) async {
    try {
      await storage.ref(ref).updateMetadata(
        SettableMetadata(
          customMetadata: {
            'description': _userDescription,
          },
        ),
      );
      // Rebuild the UI
      setState(() {});
    } catch (e) {
      if (e is FirebaseException && e.code == 'object-not-found') {
        print('File does not exist at the specified reference');
        // Handle the case where the file doesn't exist
      } else {
        // Handle other types of exceptions
        print('Error updating description: $e');
      }
    }
  }

  // Edit description form
  Future<void> _showEditForm(String ref) {
    _descriptionController.text = '';

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (param) {
        return AlertDialog(
          actions: <Widget>[
            TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(Colors.red),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
            TextButton(
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all<Color>(Colors.green),
              ),
              onPressed: () async {
                setState(() {
                  _userDescription = _descriptionController.text;
                });

                _setDescription(ref);
                imgRef.doc(ref).update({'description': _descriptionController.text});

                Navigator.pop(context);
              },
              child: Text('Update'),
            ),
          ],
          title: Text('Edit description'),
          content: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextField(
                  controller: _descriptionController,
                  decoration: InputDecoration(
                    hintText: 'Enter a new description',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Your photos'),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _upload('camera'),
                  icon: Icon(Icons.camera),
                  label: Text('Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: () => _upload('gallery'),
                  icon: Icon(Icons.library_add),
                  label: Text('Gallery'),
                ),
              ],
            ),
            Expanded(
              child: FutureBuilder(
                future: _loadImages(),
                builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                  if (snapshot.connectionState == ConnectionState.done) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('Error loading images'),
                      );
                    }

                    final images = snapshot.data;
                    if (images == null || images.isEmpty) {
                      return Center(
                        child: Text('No images found'),
                      );
                    }

                    return ListView.builder(
                      itemCount: images.length,
                      itemBuilder: (context, index) {
                        final image = images[index];
                        return Card(
                          elevation: 5,
                          margin: EdgeInsets.symmetric(vertical: 5),
                          child: ListTile(
                            dense: false,
                            leading: Image.network(image['url']),
                            title: Text(image['description']),
                            subtitle: Column(
                              children: <Widget>[
                                Text('Location: ${image['location']}'),
                                Text('Date & Time: ${image['dateTime']}'),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                IconButton(
                                  onPressed: () => _showEditForm(image['path']),
                                  icon: Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _delete(image['path']),
                                  icon: Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  }

                  return Center(
                    child: CircularProgressIndicator(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
