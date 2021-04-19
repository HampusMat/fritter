import 'dart:developer';

import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:fritter/database/entities.dart';
import 'package:fritter/group/group_screen.dart';
import 'package:fritter/home/home_screen.dart';
import 'package:fritter/home_model.dart';
import 'package:fritter/user.dart';
import 'package:provider/provider.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';
import 'package:reactive_forms/reactive_forms.dart';

class SubscriptionsContent extends StatefulWidget {
  @override
  _SubscriptionsContentState createState() => _SubscriptionsContentState();
}

class _SubscriptionsContentState extends State<SubscriptionsContent> {
  final _refreshController = RefreshController(initialRefresh: false);

  Future _onRefresh() async {
    try {
      await Future.delayed(Duration(milliseconds: 400));

      await context.read<HomeModel>().refresh();
    } finally {
      _refreshController.refreshCompleted();
    }
  }

  void openDeleteSubscriptionGroupDialog(int id, String name) {
    var model = context.read<HomeModel>();

    showDialog(context: context, builder: (context) {
      return AlertDialog(
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('No'),
          ),
          TextButton(
            onPressed: () async {
              await model.deleteSubscriptionGroup(id);

              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text('Yes'),
          ),
        ],
        title: Text('Are you sure?'),
        content: Text('Are you sure you want to delete the subscription group $name?'),
      );
    });
  }

  void openSubscriptionGroupDialog(int? id, String name) {
    var model = context.read<HomeModel>();

    showDialog(context: context, builder: (context) {
      return FutureBuilder<SubscriptionGroupEdit>(
        future: model.loadSubscriptionGroupEdit(id),
        builder: (context, snapshot) {
          var error = snapshot.error;
          if (error != null) {
            // TODO
            log('Unable to load the subscription group', error: error);
          }

          var edit = snapshot.data;
          if (edit == null) {
            // TODO: Alert
            return Center(child: CircularProgressIndicator());
          }

          final form = FormGroup({
            'name': FormControl<String>(
                value: name,
                validators: [Validators.required],
                touched: true
            ),
            'subscriptions': FormArray<bool>(
                edit.allSubscriptions
                    .map((e) => FormControl<bool>(value: edit.members.contains(e.id)))
                    .toList(growable: false)
            )
          });

          return ReactiveForm(
              formGroup: form,
              child: AlertDialog(
                actions: [
                  TextButton(
                    onPressed: id == null
                        ? null
                        : () => openDeleteSubscriptionGroupDialog(id, name),
                    child: Text('Delete'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('Cancel'),
                  ),
                  ReactiveFormConsumer(
                    builder: (context, form, child) {
                      var onPressed = () async {
                        var selectedSubscriptions = (form.control('subscriptions').value as List<bool?>)
                            .asMap().entries
                            .map((e) {
                          var index = e.key;
                          var value = e.value;
                          if (value != null && value == true) {
                            return edit.allSubscriptions[index];
                          }

                          return null;
                        })
                            .where((element) => element != null)
                            .cast<Subscription>()
                            .toList(growable: false);

                        await model.saveSubscriptionGroup(
                            id,
                            form.control('name').value,
                            selectedSubscriptions
                        );

                        Navigator.pop(context);
                      };

                      return TextButton(
                        child: Text('OK'),
                        onPressed: form.valid
                            ? onPressed
                            : null,
                      );
                    },
                  ),
                ],
                content: Container(
                  width: double.maxFinite,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ReactiveTextField(
                        formControlName: 'name',
                        decoration: InputDecoration(
                            border: UnderlineInputBorder(),
                            hintText: 'Name'
                        ),
                        validationMessages: (control) => {
                          ValidationMessage.required: 'Please enter a name',
                        },
                      ),
                      Expanded(
                        child: SubscriptionCheckboxList(
                          subscriptions: edit.allSubscriptions,
                        ),
                      )
                    ],
                  ),
                ),
              )
          );
        },
      );
    });
  }

  Widget _createGroupCard(IconData icon, int id, String name, void Function()? onLongPress) {
    return Card(
      child: InkWell(
        onTap: () {
          // Open page with the group's feed
          Navigator.push(context, MaterialPageRoute(builder: (context) => SubscriptionGroupScreen(id: id)));
        },
        onLongPress: onLongPress,
        child: Column(
          children: [
            Container(
              color: Colors.white10,
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Icon(icon, size: 16),
            ),
            Expanded(child: Container(
              alignment: Alignment.center,
              color: Colors.white24,
              width: double.infinity,
              padding: EdgeInsets.all(4),
              child: Text(name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold
                  )
              ),
            ))
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Consumer<HomeModel>(
        builder: (context, model, child) {
          return FutureBuilder<List<SubscriptionGroup>>(
            future: model.listSubscriptionGroups(),
            builder: (context, snapshot) {
              var groups = snapshot.data;
              if (groups == null) {
                return Center(child: CircularProgressIndicator());
              }

              return Column(
                children: [
                  Theme(
                    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                    child: ExpansionTile(
                      initiallyExpanded: true,
                      title: Text('Groups', style: TextStyle(
                          fontWeight: FontWeight.bold
                      )),
                      children: [
                        Container(
                          margin: EdgeInsets.symmetric(horizontal: 8),
                          child: GridView.extent(
                              maxCrossAxisExtent: 120,
                              childAspectRatio: 200 / 125,
                              shrinkWrap: true,
                              children: [
                                _createGroupCard(Icons.rss_feed, -1, 'All', null),
                                ...groups.map((e) => _createGroupCard(Icons.rss_feed, e.id, e.name, () => openSubscriptionGroupDialog(e.id, e.name))),
                                Card(
                                  child: InkWell(
                                    onTap: () {
                                      openSubscriptionGroupDialog(null, '');
                                    },
                                    child: DottedBorder(
                                      color: Colors.white,
                                      child: Container(
                                        width: double.infinity,
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Container(
                                              // color: Colors.white10,
                                              // width: double.infinity,
                                              child: Icon(Icons.add, size: 16),
                                            ),
                                            SizedBox(height: 4),
                                            Text('New', style: TextStyle(
                                              fontSize: 11,
                                            ))
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                              ]),
                        )
                      ],
                    ),
                  ),
                  Expanded(child: Column(
                    children: [
                      ListTile(
                        title: Text('Subscriptions', style: TextStyle(
                            fontWeight: FontWeight.bold
                        )),
                      ),
                      Expanded(child: FutureBuilder<List<Subscription>>(
                        future: model.listSubscriptions(),
                        builder: (context, snapshot) {
                          var error = snapshot.error;
                          if (error != null) {
                            // TODO
                            log('Unable to list the user\'s subscriptions', error: error);
                          }

                          var data = snapshot.data;
                          if (data == null) {
                            return Center(child: CircularProgressIndicator());
                          }

                          if (data.isEmpty) {
                            return Center(child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('¯\\_(ツ)_/¯', style: TextStyle(
                                      fontSize: 32
                                  )),
                                  Container(
                                    margin: EdgeInsets.symmetric(vertical: 16),
                                    child: Text('Try searching for some users to follow!', style: TextStyle(
                                        color: Theme.of(context).hintColor
                                    )),
                                  )
                                ])
                            );
                          }

                          return SmartRefresher(
                            controller: _refreshController,
                            enablePullDown: true,
                            enablePullUp: false,
                            onRefresh: _onRefresh,
                            child: ListView.builder(
                              shrinkWrap: true,
                              itemCount: data.length,
                              itemBuilder: (context, index) {
                                var user = data[index];

                                return UserTile(
                                  id: user.id.toString(),
                                  name: user.name,
                                  screenName: user.screenName,
                                  imageUri: user.profileImageUrlHttps,
                                );
                              },
                            ),
                          );
                        },
                      ))
                    ],
                  ))
                ],
              );
            },
          );
        },
      ),
    );
  }
}
