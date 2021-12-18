import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:flutter_fando/fando_client/client.dart';

class PartnersList extends StatelessWidget {
  const PartnersList({Key key, this.client}) : super(key: key);
  final Client client;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text("Partner List")),
        body: FutureBuilder<Widget>(
          future: getPartnerListView(),
          builder: (BuildContext context, AsyncSnapshot<Widget> snapshot) {
            if (snapshot.hasData) {
              return snapshot.data;
            } else {
              return Center(
                child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                        Theme.of(context).primaryColor)),
                widthFactor: 60,
                heightFactor: 60,
              );
            }
          },
        ));
  }

  Future<Widget> getPartnerListView() async {
    List<Widget> partners = await getPartnerList();
    return ListView.builder(
      itemBuilder: (context, i) {
        return ListTile(title: partners[i]);
      },
      itemCount: partners.length,
    );
  }

  Future<List<ListTile>> getPartnerList() async {
    List<Partner> partnerList = await client.getPartnerList();
    List<ListTile> list = [];
    for (int i = 0; i < partnerList.length; i++) {
      list.add(ListTile(
        leading: Image.network(partnerList[i].imageUrl, width: 72, height: 72),
        title: Text(partnerList[i].partnerName),
        subtitle:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            "1 балл " +
                partnerList[i].partnerName +
                "= " +
                partnerList[i].condition.toString() +
                " балл ФандоЛайт",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(partnerList[i].description)
        ]),
        // trailing: Icon(Icons.more_vert),
      ));
    }
    return list;
  }
}
