// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';
import 'dart:async';

Future<void> runNativeFetchImpl(String schoolId, String token, void Function(String) log) async {
  final tenantId = 'd09b9362-3dc8-422d-a441-160735fcea96';

  log('Starting native browser fetch diagnostics (no Dio)...\n');
  log('API Endpoint: http://127.0.0.1:8000/api/v1/students\n');

  final xhr = html.HttpRequest();
  xhr.open('POST', 'http://127.0.0.1:8000/api/v1/students');
  
  xhr.setRequestHeader('Content-Type', 'application/json');
  xhr.setRequestHeader('X-School-ID', schoolId);
  xhr.setRequestHeader('X-Tenant-ID', tenantId);
  if (token.isNotEmpty) {
    xhr.setRequestHeader('Authorization', 'Bearer $token');
  }

  final payload = {
    'first_name': 'Native',
    'last_name': 'FetchTest',
    'gender': 'MALE',
    'date_of_birth': '2015-05-15',
    'admission_number': 'NAT_TEST_${DateTime.now().millisecondsSinceEpoch}',
    'roll_number': 'NAT_R_${DateTime.now().millisecondsSinceEpoch}',
    'admission_date': '2026-08-01',
    'school_id': schoolId,
    'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
    'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
    'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
    'status': 'ACTIVE',
  };

  xhr.onLoad.listen((event) {
    log('\n[RESPONSE RECEIVED]\n');
    log('Status: ${xhr.status}\n');
    log('Response Body: ${xhr.responseText}\n');
    log('Response Headers: \n${xhr.responseHeaders}\n');
  });

  xhr.onError.listen((event) {
    log('\n[REQUEST BLOCKED/FAILED]\n');
    log('Status: ${xhr.status}\n');
    log('Error Details: XMLHttpRequest onError callback triggered.\n');
  });

  try {
    xhr.send(json.encode(payload));
    log('XHR request dispatched. Waiting for response...\n');
  } catch (e) {
    log('Synchronous send exception: $e\n');
  }
}

Future<void> runProgressiveTestImpl(String schoolId, String token, void Function(String) log) async {
  final tenantId = 'd09b9362-3dc8-422d-a441-160735fcea96';

  log('Starting Progressive Headers CORS isolation test...\n');

  final tests = <String, Map<String, String>>{
    'TEST A: Content-Type only': {
      'Content-Type': 'application/json',
    },
    'TEST B: Content-Type + X-School-ID': {
      'Content-Type': 'application/json',
      'X-School-ID': schoolId,
    },
    'TEST C: Content-Type + X-School-ID + X-Tenant-ID': {
      'Content-Type': 'application/json',
      'X-School-ID': schoolId,
      'X-Tenant-ID': tenantId,
    },
    'TEST D: Content-Type + X-School-ID + X-Tenant-ID + Authorization': {
      'Content-Type': 'application/json',
      'X-School-ID': schoolId,
      'X-Tenant-ID': tenantId,
      'Authorization': 'Bearer $token',
    },
  };

  for (final entry in tests.entries) {
    final name = entry.key;
    final headers = entry.value;

    log('\nExecuting $name...\n');
    final completer = Completer<void>();
    
    final xhr = html.HttpRequest();
    xhr.open('POST', 'http://127.0.0.1:8000/api/v1/students');
    
    headers.forEach((key, val) {
      if (key == 'Authorization' && token.isEmpty) return;
      xhr.setRequestHeader(key, val);
    });

    final payload = {
      'first_name': 'Progressive',
      'last_name': 'Test',
      'gender': 'MALE',
      'date_of_birth': '2015-05-15',
      'admission_number': 'PROG_${entry.key.split(" ")[1].replaceAll(":", "")}_${DateTime.now().millisecondsSinceEpoch}',
      'roll_number': 'PR_${entry.key.split(" ")[1].replaceAll(":", "")}_${DateTime.now().millisecondsSinceEpoch}',
      'admission_date': '2026-08-01',
      'school_id': schoolId,
      'academic_year_id': 'a0eebc99-9c0b-4ef8-bb6d-6bb9bd380a11',
      'class_id': 'b0eebc99-9c0b-4ef8-bb6d-6bb9bd380a22',
      'section_id': 'c0eebc99-9c0b-4ef8-bb6d-6bb9bd380a33',
      'status': 'ACTIVE',
    };

    xhr.onLoad.listen((_) {
      log('-> Status: ${xhr.status} (SUCCESS)\n');
      completer.complete();
    });

    xhr.onError.listen((event) {
      log('-> Status: ${xhr.status} (FAILED/BLOCKED BY BROWSER)\n');
      completer.complete();
    });

    try {
      xhr.send(json.encode(payload));
    } catch (e) {
      log('-> Exception during send: $e\n');
      completer.complete();
    }

    await completer.future;
    await Future.delayed(const Duration(milliseconds: 300));
  }
  log('\nProgressive Header Diagnostics complete.');
}
