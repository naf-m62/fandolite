import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';

const StatusSuccess = 0;
const StatusFailed = 1;
const StatusNotAccept = 2;
const route = "http://192.168.31.110";
const timeout = 30 * 1000; // 30s

// todo to use methods via /private route
class Client {
  BaseOptions opt = new BaseOptions(
    connectTimeout: timeout,
    receiveTimeout: timeout,
  );
  int statusCode;

  // sendOperationCreate создает операцию
  Future<void> sendOperationCreate(
      String barcode, int userID, containerID) async {
    Response response;
    Dio dio = new Dio(opt);
    try {
      response = await dio.post(
        route + "/operation",
        data: {
          "user_id": userID,
          "barcode": barcode,
          "container_id": containerID
        },
      );
    } on DioError catch (e) {
      response = e.response;
      if (response == null) {
        statusCode = StatusFailed;
        return;
      }
    }
    if (response.statusCode != 201) {
      print("status code $response.statusCode");
    }
    if (response.statusCode > 400) {
      if (response.statusCode == 422) {
        statusCode = StatusNotAccept;
      } else {
        statusCode = StatusFailed;
      }
      return;
    }

    statusCode = StatusSuccess;
    return;
  }

  // addBall добавляет балы участнику
  Future<void> addBall(int userID) async {
    Response response;
    Dio dio = new Dio(opt);
    try {
      response = await dio.put(
        route + "/ball",
        data: {
          "user_id": userID,
        },
      );
    } on DioError catch (e) {
      response = e.response;
      if (response == null) {
        statusCode = StatusFailed;
        return;
      }
    }
    if (response.statusCode != 200) {
      print("status code $response.statusCode");
    }
    if (response.statusCode > 400) {
      statusCode = StatusFailed;
      return;
    }

    statusCode = StatusSuccess;
    return;
  }

  Future<User> sessionCreate(String email, password) async {
    Response response;
    Dio dio = new Dio(opt);
    try {
      response = await dio.post(
        route + "/sessions",
        data: {
          "email": email,
          "password": password,
        },
      );
    } on DioError catch (e) {
      response = e.response;
      if (response == null) {
        statusCode = StatusFailed;
        return User();
      }
    }
    if (response.statusCode != 200) {
      print("status code $response.statusCode");
    }
    if (response.statusCode > 400) {
      statusCode = StatusFailed;
      return User();
    }

    statusCode = StatusSuccess;
    Map<String, dynamic> map = jsonDecode(response.data);
    return User.fromJson(map);
  }

  Future<User> getUserInfo(int userID) async {
    Response response;
    Dio dio = new Dio(opt);
    try {
      response =
          await dio.get(route + "/info", queryParameters: {"userId": userID});
    } on DioError catch (e) {
      response = e.response;
      if (response == null) {
        statusCode = StatusFailed;
        return User();
      }
    }
    if (response.statusCode != 200) {
      print("status code " +
          response.statusCode.toString() +
          " statusMessage: " +
          response.statusMessage);
    }
    if (response.statusCode > 400) {
      statusCode = StatusFailed;
      return User();
    }

    statusCode = StatusSuccess;
    Map<String, dynamic> map = jsonDecode(response.data);
    return User.fromJson(map);
  }

  Future<List<Partner>> getPartnerList() async {
    Response response;
    Dio dio = new Dio(opt);
    try {
      response = await dio.get(
        route + "/partners",
      );
    } on DioError catch (e) {
      response = e.response;
      if (response == null) {
        statusCode = StatusFailed;
        return null;
      }
    }
    if (response.statusCode != 200) {
      print("status code " +
          response.statusCode.toString() +
          " statusMessage: " +
          response.statusMessage);
    }
    if (response.statusCode > 400) {
      statusCode = StatusFailed;
      return null;
    }

    statusCode = StatusSuccess;
    List<Partner> partnerList = (jsonDecode(response.data) as List)
        .map((e) => Partner.fromJson(e))
        .toList();
    return partnerList;
  }
}

@JsonSerializable()
class User {
  User({
    this.id,
    this.balls,
  });
  @JsonKey(name: "id")
  int id;

  @JsonKey(name: "balls")
  int balls;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        balls: json['balls'] as int,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'balls': balls,
      };
}

@JsonSerializable()
class Partner {
  Partner({
    this.id,
    this.partnerName,
    this.description,
    this.condition,
    this.imageUrl,
  });
  @JsonKey(name: "id")
  int id;

  @JsonKey(name: "partnerName")
  String partnerName;

  @JsonKey(name: "description")
  String description;

  @JsonKey(name: "condition")
  int condition;

  @JsonKey(name: "imageUrl")
  String imageUrl;

  factory Partner.fromJson(Map<String, dynamic> json) => Partner(
        id: json['id'] as int,
        partnerName: json['partnerName'] as String,
        description: json['description'] as String,
        condition: json['condition'] as int,
        imageUrl: json['imageUrl'] as String,
      );
  Map<String, dynamic> toJson() => {
        'id': id,
        'partnerName': partnerName,
        'description': description,
        'condition': condition,
        'imageUrl': imageUrl,
      };
}
