import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:ui';

import 'package:ZY_Player_flutter/Collect/provider/collect_provider.dart';
import 'package:ZY_Player_flutter/model/detail_reource.dart';
import 'package:ZY_Player_flutter/net/dio_utils.dart';
import 'package:ZY_Player_flutter/net/http_api.dart';
import 'package:ZY_Player_flutter/player/provider/detail_provider.dart';
import 'package:ZY_Player_flutter/provider/theme_provider.dart';
import 'package:ZY_Player_flutter/res/colors.dart';
import 'package:ZY_Player_flutter/res/resources.dart';
import 'package:ZY_Player_flutter/util/log_utils.dart';
import 'package:ZY_Player_flutter/util/toast.dart';
import 'package:ZY_Player_flutter/utils/provider.dart';
import 'package:ZY_Player_flutter/widgets/app_bar.dart';
import 'package:ZY_Player_flutter/widgets/my_card.dart';
import 'package:ZY_Player_flutter/widgets/state_layout.dart';
import 'package:fijkplayer/fijkplayer.dart';
import 'package:flustars/flustars.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../model/detail_reource.dart';

class PlayerDetailPage extends StatefulWidget {
  const PlayerDetailPage({
    Key key,
    @required this.url,
    @required this.title,
  }) : super(key: key);

  final String url;
  final String title;

  @override
  _PlayerDetailPageState createState() => _PlayerDetailPageState();
}

class _PlayerDetailPageState extends State<PlayerDetailPage> with WidgetsBindingObserver {
  final FijkPlayer _player = FijkPlayer();

  bool startedPlaying = false;

  DetailProvider _detailProvider = DetailProvider();
  CollectProvider _collectProvider;
  ThemeProvider _themeProvider;
  StreamSubscription _currentPosSubs;

  String actionName = "";
  bool _isFullscreen = false;

  int currentVideoIndex = -1;

  String currentUrl = "";

  @override
  void initState() {
    WidgetsBinding.instance.addObserver(this);
    _collectProvider = Store.value<CollectProvider>(context);
    _themeProvider = Store.value<ThemeProvider>(context);
    _collectProvider.setListDetailResource("collcetPlayer");
    _player.addListener(_fijkValueListener);

    initData();
    huanchong();
    super.initState();
  }

  void huanchong() {
    _currentPosSubs = _player.onBufferStateUpdate.listen((v) {
      _detailProvider.setBufferState(v);
    });
  }

  Future _fijkValueListener() async {
    FijkValue value = _player.value;
    _isFullscreen = value.fullScreen;
  }

  void toggleFullscreen() {
    _isFullscreen = !_isFullscreen;
    _isFullscreen ? SystemChrome.setEnabledSystemUIOverlays([]) : SystemChrome.setEnabledSystemUIOverlays(SystemUiOverlay.values);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print('app lifecycle state: $state');
    if (state == AppLifecycleState.inactive) {
      _player.pause();
    } else if (state == AppLifecycleState.resumed) {
      _player.start();
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  void dispose() {
    super.dispose();
    _player.removeListener(_fijkValueListener);
    _player.release();
    _currentPosSubs?.cancel();
  }

  Future getPlayVideoUrl(String videoUrl) async {
    await DioUtils.instance.requestNetwork(Method.get, HttpApi.getPlayVideoUrl, queryParameters: {"url": videoUrl}, onSuccess: (data) {
      currentUrl = data;
    }, onError: (_, __) {});
  }

  Future initData() async {
    _detailProvider.setStateType(StateType.loading);
    await DioUtils.instance.requestNetwork(Method.get, HttpApi.detailReource, queryParameters: {"url": widget.url}, onSuccess: (data) {
      _detailProvider.setDetailResource(DetailReource.fromJson(data[0]));
      _detailProvider.setJuji();
      _collectProvider.changeNoti();
      setPlayerVideo();
      if (getFilterData(_detailProvider.detailReource)) {
        _detailProvider.setActionName("点击取消");
      } else {
        _detailProvider.setActionName("点击收藏");
      }
      _detailProvider.setStateType(StateType.empty);
    }, onError: (_, __) {
      _detailProvider.setStateType(StateType.network);
    });
  }

  Future setPlayerVideo() async {
    await _player.applyOptions(FijkOption()
      ..setFormatOption('fflags', 'fastseek')
      ..setHostOption('request-screen-on', 1)
      ..setHostOption('request-audio-focus', 1)
      ..setCodecOption('cover-after-prepared', 1)
      ..setPlayerOption('framedrop', 5)
      ..setPlayerOption('packet-buffering', 1)
      ..setPlayerOption('mediacodec', 1)
      ..setPlayerOption('enable-accurate-seek', 1)
      ..setPlayerOption('reconnect', 5)
      ..setPlayerOption('render-wait-start', 1));
  }

  bool getFilterData(DetailReource data) {
    if (data != null) {
      var result = _collectProvider.listDetailResource.where((element) => element.url == data.url).toList();
      return result.length > 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData themeData = Theme.of(context);
    final bool isDark = themeData.brightness == Brightness.dark;

    return ChangeNotifierProvider<DetailProvider>(
        create: (_) => _detailProvider,
        child: Scaffold(
          appBar: PreferredSize(
              preferredSize: Size.fromHeight(48.0),
              child: Selector<DetailProvider, String>(
                  builder: (_, actionName, __) {
                    return MyAppBar(
                        centerTitle: widget.title,
                        actionName: actionName,
                        onPressed: () {
                          if (getFilterData(_detailProvider.detailReource)) {
                            Log.d("点击取消");
                            _collectProvider.removeResource(_detailProvider.detailReource.url);
                            _detailProvider.setActionName("点击收藏");
                          } else {
                            Log.d("点击收藏");
                            _collectProvider.addResource(
                              _detailProvider.detailReource,
                            );
                            _detailProvider.setActionName("点击取消");
                          }
                        });
                  },
                  selector: (_, store) => store.actionName)),
          body: Consumer<DetailProvider>(builder: (_, provider, __) {
            return provider.detailReource != null
                ? Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            width: MediaQuery.of(context).size.width,
                            height: ScreenUtil.getInstance().getWidth(230),
                            child: FijkView(
                              player: _player,
                              color: Colors.black,
                              panelBuilder: fijkPanel2Builder(
                                  snapShot: true,
                                  fill: true,
                                  onBack: () {
                                    _player.exitFullScreen();
                                  }),
                              fsFit: FijkFit.fill,
                            ),
                          ),
                        ],
                      ),
                      Expanded(
                          child: CustomScrollView(
                        slivers: <Widget>[
                          SliverToBoxAdapter(
                            child: MyCard(
                              child: Container(
                                padding: EdgeInsets.all(10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text("剧情介绍"),
                                    Text(
                                      provider.detailReource.content,
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 10,
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ),
                          SliverToBoxAdapter(
                            child: provider.detailReource.videoList.length > 0
                                ? MyCard(
                                    child: Container(
                                    padding: EdgeInsets.only(left: 10, right: 10, bottom: 10),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.start,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: <Widget>[
                                        Padding(
                                          padding: EdgeInsets.only(top: 10, bottom: 10),
                                          child: Text(
                                            "剧集选择",
                                            style: TextStyle(fontSize: 15),
                                          ),
                                        ),
                                        Wrap(
                                          spacing: 20, // 主轴(水平)方向间距
                                          runSpacing: 10, // 纵轴（垂直）方向间距
                                          alignment: WrapAlignment.start, //沿主轴方向居中
                                          children: List.generate(provider.detailReource.videoList.length, (index) {
                                            return InkWell(
                                                onTap: () async {
                                                  if (currentVideoIndex == index) return;
                                                  currentVideoIndex = index;
                                                  _themeProvider.setloadingState(true);
                                                  Toast.show("正在解析地址");
                                                  await getPlayVideoUrl(_detailProvider.detailReource.videoList[currentVideoIndex].url);
                                                  _detailProvider.saveJuji("${widget.url}_$index");
                                                  _player.reset().then((value) {
                                                    _player.setDataSource(currentUrl, autoPlay: true);
                                                    Toast.show("开始播放第${currentVideoIndex + 1}集");
                                                    _themeProvider.setloadingState(false);
                                                    // 自动全屏
                                                    _player.enterFullScreen();
                                                  });
                                                },
                                                child: Container(
                                                    width: ScreenUtil.getInstance().getWidth(100),
                                                    padding: EdgeInsets.all(10),
                                                    decoration: BoxDecoration(
                                                        color: _detailProvider.kanguojuji.contains("${widget.url}_$index")
                                                            ? Colors.redAccent
                                                            : Colors.blueAccent,
                                                        borderRadius: BorderRadius.all(Radius.circular(5))),
                                                    alignment: Alignment.center,
                                                    child: Text(
                                                      '${_detailProvider.detailReource.videoList[index].title}',
                                                      style: TextStyle(
                                                        color: isDark ? Colours.dark_text : Colors.white,
                                                      ),
                                                    )));
                                          }),
                                        )
                                      ],
                                    ),
                                  ))
                                : Container(),
                          )
                        ],
                      ))
                    ],
                  )
                : StateLayout(
                    type: provider.stateType,
                    onRefresh: initData,
                  );
          }),
        ));
  }
}
