import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Directory appDocDir = await getApplicationDocumentsDirectory();
  await Hive.initFlutter(appDocDir.path);
  Hive.registerAdapter(EventAdapter());
  Hive.registerAdapter(DelegateAdapter());
  await Hive.openBox<Event>('events');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Aplicación de Delegados Políticos',
      theme: ThemeData(
        primaryColor: const Color(0xFFEF5350),
        colorScheme: ColorScheme.fromSwatch()
            .copyWith(secondary: const Color(0xFFFFEB3B)),
        scaffoldBackgroundColor: Colors.white,
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(color: Color(0xFFEF5350)),
      ),
      home: const PantallaListaEventos(),
    );
  }
}

class PantallaListaEventos extends StatelessWidget {
  const PantallaListaEventos({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lista de Eventos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.info),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PantallaInfoDelegado(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _borrarTodosLosEventos(context);
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<Box<Event>>(
        valueListenable: Hive.box<Event>('events').listenable(),
        builder: (context, box, _) {
          final eventos = box.values.toList().cast<Event>();
          return ListView.builder(
            itemCount: eventos.length,
            itemBuilder: (context, index) {
              final evento = eventos[index];
              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: ListTile(
                  title: Text(evento.titulo),
                  subtitle: Text(evento.fecha.toString()),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            PantallaDetalleEvento(evento: evento),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => const PantallaAgregarEvento()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  static void _borrarTodosLosEventos(BuildContext context) async {
    final confirmacion = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Eliminar todos los eventos?'),
        content: const Text('Esta acción no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('CANCELAR'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );

    if (confirmacion == true) {
      await Hive.box<Event>('events').clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todos los eventos han sido eliminados'),
        ),
      );
    }
  }
}

class PantallaAgregarEvento extends StatefulWidget {
  const PantallaAgregarEvento({super.key});

  @override
  _PantallaAgregarEventoState createState() => _PantallaAgregarEventoState();
}

class _PantallaAgregarEventoState extends State<PantallaAgregarEvento> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _descripcionController = TextEditingController();
  String? _rutaFoto;
  String? _rutaAudio;
  final picker = ImagePicker();
  final FlutterSoundRecorder _flutterSoundRecorder = FlutterSoundRecorder();

  bool _grabando = false;

  Future<void> _seleccionarFoto() async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _rutaFoto = pickedFile.path;
      });
    }
  }

  Future<void> _grabarAudio() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permiso de micrófono denegado'),
        ),
      );
      return;
    }

    if (!_grabando) {
      try {
        final appDocDir = await getApplicationDocumentsDirectory();
        final rutaArchivo =
            '${appDocDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
        await _flutterSoundRecorder.openRecorder();

        await _flutterSoundRecorder.startRecorder(
            toFile: rutaArchivo, codec: Codec.aacMP4);
        setState(() {
          _rutaAudio = rutaArchivo;
          _grabando = true;
        });
      } catch (e) {
        print('Error al grabar audio: $e');
      }
    } else {
      try {
        await _flutterSoundRecorder.stopRecorder();
        setState(() {
          _grabando = false;
        });
      } catch (e) {
        print('Error al detener la grabación: $e');
      }
    }
  }

  @override
  void dispose() {
    _flutterSoundRecorder.closeRecorder();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agregar Evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa un título';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor ingresa una descripción';
                  }
                  return null;
                },
              ),
              ElevatedButton(
                onPressed: _seleccionarFoto,
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(const Color(0xFFEF5350)),
                ),
                child: const Text('Seleccionar Foto'),
              ),
              ElevatedButton(
                onPressed: _grabarAudio,
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(const Color(0xFFEF5350)),
                ),
                child: Text(_grabando ? 'Detener Grabación' : 'Grabar Audio'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    final nuevoEvento = Event(
                      titulo: _tituloController.text,
                      fecha: DateTime.now(),
                      descripcion: _descripcionController.text,
                      rutaFoto: _rutaFoto ?? '',
                      rutaAudio: _rutaAudio ?? '',
                    );
                    Hive.box<Event>('events').add(nuevoEvento);
                    Navigator.pop(context);
                  }
                },
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(const Color(0xFFEF5350)),
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PantallaDetalleEvento extends StatelessWidget {
  final Event evento;

  const PantallaDetalleEvento({super.key, required this.evento});

  void _reproducirAudio(String rutaAudio) async {
    FlutterSoundPlayer _flutterSoundPlayer = FlutterSoundPlayer();
    try {
      await _flutterSoundPlayer.openPlayer();
      await _flutterSoundPlayer.startPlayer(fromURI: rutaAudio);
    } catch (e) {
      print('Error al reproducir audio: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles del Evento'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              evento.titulo,
              style:
                  const TextStyle(fontSize: 24.0, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Text(
              evento.fecha.toString(),
              style: const TextStyle(fontSize: 16.0),
            ),
            const SizedBox(height: 8.0),
            Text(
              evento.descripcion,
              style: const TextStyle(fontSize: 16.0),
            ),
            if (evento.rutaFoto.isNotEmpty) Image.file(File(evento.rutaFoto)),
            if (evento.rutaAudio.isNotEmpty) ...[
              const SizedBox(height: 16.0),
              ElevatedButton(
                onPressed: () {
                  _reproducirAudio(evento.rutaAudio);
                },
                style: ButtonStyle(
                  backgroundColor:
                      MaterialStateProperty.all<Color>(const Color(0xFFEF5350)),
                ),
                child: const Text('Reproducir Audio'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PantallaInfoDelegado extends StatelessWidget {
  const PantallaInfoDelegado({super.key});

  @override
  Widget build(BuildContext context) {
    final delegate = Delegate(
      rutaFoto: 'assets/foto.jpeg', // Agrega aquí la ruta de tu foto
      nombre: 'Edwin Paredes Hidalgo',
      matricula: '2022-0723',
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Card(
          elevation: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (delegate.rutaFoto.isNotEmpty)
                    SizedBox(
                      width: 80.0,
                      height: 80.0,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(40.0),
                        child: Image.file(
                          File(delegate.rutaFoto),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  const SizedBox(width: 16.0),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delegate.nombre,
                        style: const TextStyle(
                            fontSize: 20.0, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Matrícula: ${delegate.matricula}',
                        style: const TextStyle(fontSize: 16.0),
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 16.0),
              const Padding(
                padding: EdgeInsets.only(left: 16.0),
                child: Text(
                  'Reflexión: La democracia es el gobierno del pueblo, por el pueblo y para el pueblo.',
                  style: TextStyle(fontSize: 16.0),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class Event {
  String titulo;
  DateTime fecha;
  String descripcion;
  String rutaFoto;
  String rutaAudio;

  Event({
    required this.titulo,
    required this.fecha,
    required this.descripcion,
    this.rutaFoto = '',
    this.rutaAudio = '',
  });
}

class Delegate {
  String rutaFoto;
  String nombre;
  String matricula;

  Delegate({
    required this.rutaFoto,
    required this.nombre,
    required this.matricula,
  });
}

class EventAdapter extends TypeAdapter<Event> {
  @override
  final int typeId = 0;

  @override
  Event read(BinaryReader reader) {
    return Event(
      titulo: reader.readString(),
      fecha: DateTime.parse(reader.readString()),
      descripcion: reader.readString(),
      rutaFoto: reader.readString(),
      rutaAudio: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Event obj) {
    writer.writeString(obj.titulo);
    writer.writeString(obj.fecha.toIso8601String());
    writer.writeString(obj.descripcion);
    writer.writeString(obj.rutaFoto);
    writer.writeString(obj.rutaAudio);
  }
}

class DelegateAdapter extends TypeAdapter<Delegate> {
  @override
  final int typeId = 1;

  @override
  Delegate read(BinaryReader reader) {
    return Delegate(
      rutaFoto: reader.readString(),
      nombre: reader.readString(),
      matricula: reader.readString(),
    );
  }

  @override
  void write(BinaryWriter writer, Delegate obj) {
    writer.writeString(obj.rutaFoto);
    writer.writeString(obj.nombre);
    writer.writeString(obj.matricula);
  }
}
