import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:vendor_box/models/vendor_model.dart';

class StoreService {
  final _firestore = FirebaseFirestore.instance;

  // ดึง store hours จาก vendor doc
  Future<Map<String, dynamic>?> getStoreHours() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await _firestore.collection('vendors').doc(uid).get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final vendor = VendorModel.fromJson(data);
      return vendor.storeHours;
    }
    return null;
  }

  // บันทึก store hours (ใช้แทน controller ถ้าต้องการ)
  Future<void> saveStoreHours(Map<String, dynamic> hours) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await _firestore.collection('vendors').doc(uid).update({
      'storeHours': hours,
    });
  }

  // Stream สำหรับ real-time update (ใช้ใน orders page ถ้าต้องการ)
  Stream<Map<String, dynamic>?> streamStoreHours() {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    return _firestore.collection('vendors').doc(uid).snapshots().map((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final vendor = VendorModel.fromJson(data);
        return vendor.storeHours;
      }
      return null;
    });
  }
}
