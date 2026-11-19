import '../models/municipality.dart';

abstract interface class MunicipalityRepository {
  Future<List<Municipality>> listMunicipalities();
}
