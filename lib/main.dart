import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:simcrypter/simcrypter.dart';

void main() => runApp(SimcrypterApp());

class SimcrypterApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Simcrypter',
      theme: ThemeData.dark(),
      home: SimcrypterHome(title: 'Simcrypter'),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SimcrypterHome extends StatefulWidget {
  SimcrypterHome({Key? key, this.title}) : super(key: key);
  final String? title;

  @override
  _SimcrypterHomeState createState() => _SimcrypterHomeState();
}

class _SimcrypterHomeState extends State<SimcrypterHome> {
  late TextEditingController _inputTextController, _outputTextController;
  final ButtonStyle _tealButtonStyle = TextButton.styleFrom(
    primary: Colors.black87,
    backgroundColor: Colors.teal,
  );
  final _encrypter = Encrypter();
  final _decrypter = Decrypter();
  String _inputLengthWarning = '';

  /// Stores deleted text for an undo operation.
  Map<TextEditingController, String> _stringBuffer = {};

  @override
  void initState() {
    _inputTextController = TextEditingController();
    _outputTextController = TextEditingController();
    super.initState();
  }

  @override
  void dispose() {
    _inputTextController.dispose();
    _outputTextController.dispose();
    super.dispose();
  }

  /// Displays a custom [Alert].
  void _showAlert(
      {String? title,
      String? text,
      Color? titleColor,
      Color? textColor,
      AlertType? type,
      List<DialogButton>? buttons,
      Widget? content,
      bool? closeBtn}) {
    Alert(
      context: context,
      title: title ?? 'ALERT',
      desc: text,
      type: type ?? AlertType.none,
      buttons: buttons ?? [_button()],
      content: content ?? SizedBox(width: 0, height: 0),
      style: AlertStyle(
        titleStyle: TextStyle(color: titleColor),
        descStyle: TextStyle(color: textColor),
        isCloseButton: closeBtn ?? true,
      ),
    ).show();
  }

  /// Displays an error message in an [Alert].
  void _displayError({String? msg}) {
    String errMsg = msg ?? 'Unknown error.';
    _showAlert(
      title: 'ERROR',
      titleColor: Colors.redAccent,
      text: errMsg,
      textColor: Colors.teal,
      type: AlertType.error,
    );
  }

  /// A button for an [Alert].
  DialogButton _button({String? text, VoidCallback? action}) {
    return DialogButton(
      child: Text(
        text ?? 'OK',
        style: TextStyle(color: Colors.black54, fontSize: 20),
      ),
      onPressed: action ?? () => Navigator.pop(context),
      color: Colors.teal,
    );
  }

  /// Encrypts message and displays the encryption key or an error.
  void _encrypt() {
    try {
      String enc = _encrypter.encrypt(_inputTextController.text);
      setState(() => _outputTextController.text = enc);
      print('Key: ${_encrypter.key}');
      _showAlert(
        title: 'SUCCESS',
        titleColor: Colors.green[400],
        text: 'Your key is\n' + _encrypter.key!,
        textColor: Colors.teal,
        type: AlertType.success,
        buttons: [
          _button(
            text: 'COPY KEY',
            action: () {
              Clipboard.setData(ClipboardData(text: _encrypter.key));
              _snackBarNotif("Key copied to clipboard.");
              Navigator.pop(context);
            },
          ),
        ],
      );
    } on InvalidInputException catch (e) {
      _displayError(msg: e.toString());
    } on FatalException catch (e) {
      _showAlert(
        title: 'FATAL ERROR',
        titleColor: Colors.redAccent,
        text: e.toString(),
        textColor: Colors.redAccent,
        type: AlertType.error,
        buttons: [
          _button(
            text: 'EXIT',
            action: () => SystemNavigator.pop(),
          ),
        ],
      );
    } catch (e) {
      print('Error: ${e.toString()}');
      _displayError(msg: e.toString());
    }
  }

  /// Accepts key input from user.
  void _getKey() {
    if (_inputTextController.text.length != 0) {
      TextEditingController key = TextEditingController();
      Widget content = TextField(
        controller: key,
        maxLength: 6,
      );
      _showAlert(
        title: 'ENTER KEY',
        titleColor: Colors.teal,
        text: 'Enter $keyLength digit key:',
        textColor: Colors.teal,
        type: AlertType.info,
        buttons: [
          _button(
            text: 'SUBMIT',
            action: () {
              Navigator.pop(context);
              _decrypt(key.text);
            },
          ),
        ],
        content: content,
      );
    } else {
      _displayError(msg: 'Input is empty.');
    }
  }

  /// Decrypts input and displays the decrypted input or an error.
  void _decrypt(String key) {
    try {
      if (key == '') throw InvalidKeyException('Blank key.');
      String msg = _decrypter.decrypt(_inputTextController.text, key);
      setState(() => _outputTextController.text = msg);
      _showAlert(
        title: 'SUCCESS',
        titleColor: Colors.green[400],
        text: 'Input successfully decrypted.',
        textColor: Colors.teal,
        type: AlertType.success,
      );
    } on InvalidKeyException catch (e) {
      _displayError(msg: e.toString());
    } on Exception catch (e) {
      print('Error: ${e.toString()}');
      _displayError(msg: e.toString());
    }
  }

  /// Generates a QR code for output.
  void _generateQR() {
    try {
      if (_outputTextController.text.length == 0)
        throw QRCodeException('Output is empty.');
      String data = _outputTextController.text;
      QrImage qr = QrImage(
        data: data,
        version: QrVersions.auto,
        padding: EdgeInsets.all(8.0),
        foregroundColor: Colors.black87,
        backgroundColor: Colors.teal,
      );
      _showAlert(
        title: 'Output QR Code',
        content: Padding(
          padding: EdgeInsets.all(10.0),
          child: Container(
            width: 255.0,
            height: 255.0,
            child: qr,
          ),
        ),
        titleColor: Colors.teal,
        closeBtn: false,
      );
    } on InputTooLongException {
      _displayError(msg: "Output is too log for QR code.");
    } on QRCodeException catch (e) {
      _displayError(msg: e.toString());
    } catch (e) {
      print('Error: ${e.toString()}');
      _displayError(msg: e.toString());
    }
  }

  /// Displays app info.
  void _about() {
    String info = 'A simple app for encrpyting and decrypting text.\n'
        'Encryption and decryption is done via a substitution cipher.\n';
    Alert(
      context: context,
      title: 'ABOUT',
      type: AlertType.info,
      content: Column(
        children: <Widget>[
          Text(
            info,
            style: TextStyle(color: Colors.teal, fontSize: 20),
            textAlign: TextAlign.center,
          ),
          _button(
              text: 'DISCLAIMER',
              action: () {
                Navigator.pop(context);
                _disclaimer();
              }),
          _button(),
        ],
      ),
      buttons: [],
      style: AlertStyle(titleStyle: TextStyle(color: Colors.orange)),
    ).show();
  }

  /// Displays the app disclaimer.
  void _disclaimer() {
    String info = 'This app is meant for fun and personal use and has not been '
        'vetted by cryptography security professionals. Please do not use this '
        'app as a substitute for cryptographically secure tools.\nI accept no '
        'liability or responsibility to any person as a consequence of any '
        'reliance upon the services of this app.';
    _showAlert(
      title: 'DISCLAIMER',
      titleColor: Colors.orange,
      text: info,
      textColor: Colors.teal,
      type: AlertType.warning,
    );
  }

  /// Un-focuses the active text field to get rid of the keyboard.
  void _unfocusTextField() {
    FocusScopeNode currFocus = FocusScope.of(context);
    if (!currFocus.hasPrimaryFocus) currFocus.unfocus();
  }

  /// Displays a [SnackBar] notification.
  void _snackBarNotif(String message,
          {String? actionName, VoidCallback? action}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange,
        action: SnackBarAction(
          label: actionName ?? '',
          onPressed: action ?? () {},
        ),
        duration: Duration(seconds: 2),
      ));

  /// Delete text from [TextField] to which [controller] is attached.
  ///
  /// Deleted text is stored in a buffer in case the user wants to undo the
  /// delete operation.
  void _deleteText(TextEditingController controller) {
    _stringBuffer[controller] = controller.text;
    controller.clear();
  }

  /// Copy previously deleted text from buffer onto [TextField] to which
  /// [controller] is attached.
  ///
  /// Buffer is subsequently cleared to prevent miscopying.
  void _undoDeleteText(TextEditingController controller) {
    setState(() => controller.text = _stringBuffer[controller]!);
    _stringBuffer[controller] = '';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints viewportConstraints) {
            return GestureDetector(
              onTap: () => _unfocusTextField(),
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: viewportConstraints.maxHeight,
                  ),
                  child: IntrinsicHeight(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SizedBox(
                          height: 25.0,
                        ),
                        Flexible(
                          flex: 1,
                          child: Center(
                            child: Text(
                              'SIMCRYPTER',
                              style: TextStyle(
                                color: Colors.orange,
                                fontFamily: 'MajorMono',
                                fontSize: 40.0,
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 5.0, horizontal: 25.0),
                          child: Text('input:'),
                        ),
                        Flexible(
                          flex: 2,
                          child: Container(
                            height: 150,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 0.0, horizontal: 25.0),
                                child: TextField(
                                  decoration: InputDecoration(
                                    hintText:
                                        'Enter Some Text (Between $minMsgLength and $maxMsgLength Characters)',
                                    hintStyle:
                                        TextStyle(fontFamily: 'OpenSans'),
                                    helperText: _inputLengthWarning,
                                    helperStyle:
                                        TextStyle(color: Colors.orange),
                                    counterText:
                                        '${_inputTextController.text.length}/$maxMsgLength',
                                    counterStyle: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .secondary),
                                    border: const OutlineInputBorder(),
                                  ),
                                  controller: _inputTextController,
                                  keyboardType: TextInputType.multiline,
                                  maxLines: 20,
                                  onChanged: (text) {
                                    setState(() {
                                      _inputLengthWarning =
                                          (text.length >= maxMsgLength)
                                              ? 'Max character limit reached'
                                              : '';
                                    });
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: <Widget>[
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 0.0, horizontal: 10.0),
                                child: TextButton(
                                  style: _tealButtonStyle,
                                  onPressed: () {
                                    _getKey();
                                    _unfocusTextField();
                                  },
                                  child: Text(
                                    'DECRYPT',
                                    style: TextStyle(fontFamily: 'OpenSans'),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 0.0, horizontal: 10.0),
                                child: TextButton(
                                  style: _tealButtonStyle,
                                  onPressed: () {
                                    _encrypt();
                                    _unfocusTextField();
                                  },
                                  child: Text(
                                    'ENCRYPT',
                                    style: TextStyle(fontFamily: 'OpenSans'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          height: 25.0,
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 5.0, horizontal: 25.0),
                          child: Text('output:'),
                        ),
                        Flexible(
                          flex: 2,
                          child: Container(
                            height: 150,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 0.0, horizontal: 25.0),
                                child: TextField(
                                  readOnly: true,
                                  decoration: InputDecoration(
                                    hintText: 'Encryption/decryption Result',
                                    hintStyle:
                                        TextStyle(fontFamily: 'OpenSans'),
                                    border: const OutlineInputBorder(),
                                  ),
                                  controller: _outputTextController,
                                  keyboardType: TextInputType.multiline,
                                  minLines: 20,
                                  maxLines: null,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Flexible(
                          flex: 1,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 10.0),
                                child: TextButton(
                                  style: _tealButtonStyle,
                                  onPressed: () {
                                    Clipboard.setData(ClipboardData(
                                        text: _outputTextController.text));
                                    _snackBarNotif(
                                        "Output copied to clipboard.");
                                  },
                                  child: Text(
                                    'COPY OUTPUT',
                                    style: TextStyle(fontFamily: 'OpenSans'),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10.0, horizontal: 10.0),
                                child: TextButton(
                                  style: _tealButtonStyle,
                                  onPressed: _generateQR,
                                  child: Text(
                                    'GENERATE QR',
                                    style: TextStyle(fontFamily: 'OpenSans'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: Colors.orange,
        foregroundColor: Colors.black87,
        child: PopupMenuButton(
          icon: Icon(Icons.more_horiz),
          onCanceled: () {},
          onSelected: (int option) {
            if (option == 0) _about();
            if (option == 1) {
              _deleteText(_inputTextController);
              _snackBarNotif(
                "Input cleared.",
                actionName: 'UNDO',
                action: () => _undoDeleteText(_inputTextController),
              );
              setState(() => _inputLengthWarning = '');
            } else if (option == 2) {
              _deleteText(_outputTextController);
              _snackBarNotif(
                "Output cleared.",
                actionName: 'UNDO',
                action: () => _undoDeleteText(_outputTextController),
              );
            } else if (option == 3) {
              _deleteText(_inputTextController);
              _deleteText(_outputTextController);
              _snackBarNotif(
                "Input and output cleared.",
                actionName: 'UNDO',
                action: () {
                  _undoDeleteText(_inputTextController);
                  _undoDeleteText(_outputTextController);
                },
              );
              setState(() => _inputLengthWarning = '');
            } else
              DoNothingAction();
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<int>>[
            PopupMenuItem<int>(
              value: 0,
              child: ListTile(
                leading: Icon(
                  Icons.info_outline,
                  color: Colors.orange,
                ),
                title: Text('About'),
              ),
            ),
            PopupMenuItem<int>(
              value: 1,
              child: ListTile(
                leading: Icon(
                  Icons.clear,
                  color: Colors.orange,
                ),
                title: Text('Clear Input'),
              ),
            ),
            PopupMenuItem<int>(
              value: 2,
              child: ListTile(
                leading: Icon(
                  Icons.clear,
                  color: Colors.orange,
                ),
                title: Text('Clear Output'),
              ),
            ),
            PopupMenuItem<int>(
              value: 3,
              child: ListTile(
                leading: Icon(
                  Icons.clear,
                  color: Colors.orange,
                ),
                title: Text('Clear All'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
