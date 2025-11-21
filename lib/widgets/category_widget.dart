// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:vendor_box/services/sevice.dart';

class CategoryWidget extends StatelessWidget {
  const CategoryWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final Stream<QuerySnapshot> _categoriesStream = FirebaseFirestore.instance
        .collection('type')
        .snapshots();
    return StreamBuilder<QuerySnapshot>(
      stream: _categoriesStream,
      builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
        if (snapshot.hasError) {
          return const Text('Something went wrong');
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.cyan),
          );
        }

        return SizedBox(
          height: 370,
          child: ListView.builder(
            shrinkWrap: true,
            padding: const EdgeInsets.only(top: 6, bottom: 20),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final cateData = snapshot.data!.docs[index];
              return Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  cateData['typename'],
                  style: styles(letterSpacing: 1),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
