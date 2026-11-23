import '../../domain/tv_driver_contract.dart';
import '../../models/cue_models.dart';
import 'arcelik_vestel_upnp_driver.dart';
import 'ir_blaster_driver.dart';
import 'lg_webos_driver.dart';
import 'roku_philips_vidaa_driver.dart';
import 'samsung_tizen_driver.dart';

/// OCP-compliant Registry mapping every [TvConnectionProtocol] to its concrete [TvRemoteDriver].
/// Adding a new Smart TV protocol only requires registering an entry here without touching UI or core dispatchers.
class TvDriverRegistry {
  TvDriverRegistry({
    required TvSecretVault vault,
    required LanSocketFactory openLanSocket,
    required Map<String, String> ssdpLocationUrls,
    required Map<String, String> dialAppUrls,
    TvDiagLogger? logger,
  }) {
    final upnp = UpnpDlnaDriver(
      ssdpLocationUrls: ssdpLocationUrls,
      logger: logger,
    );
    final arcelik = ArcelikGrundigDriver(
      openLanSocket: openLanSocket,
      upnpFallback: upnp,
      dialAppUrls: dialAppUrls,
      logger: logger,
    );
    final vestel = VestelSmartCenterDriver(arcelikDelegate: arcelik);
    final samsung = SamsungTizenDriver(vault: vault, logger: logger);
    final lg = LgWebOsDriver(vault: vault, logger: logger);
    final philips = PhilipsJointSpaceDriver(vault: vault, logger: logger);
    final roku = RokuEcpDriver(logger: logger);
    final vidaa = VidaaSmartDriver(vault: vault, logger: logger);
    final sony = SonyBraviaIrccDriver(vault: vault, logger: logger);
    final ir = IrBlasterDriver(logger: logger);

    arcelikDriver = arcelik;
    samsungDriver = samsung;
    lgDriver = lg;
    rokuDriver = roku;
    irBlasterDriver = ir;
    philipsDriver = philips;
    vidaaDriver = vidaa;
    _drivers = <TvConnectionProtocol, TvRemoteDriver>{
      TvConnectionProtocol.arcelikGrundig8085: arcelik,
      TvConnectionProtocol.vestelSmart56789: vestel,
      TvConnectionProtocol.samsungTizen8001: samsung,
      TvConnectionProtocol.lgWebOs3000: lg,
      TvConnectionProtocol.philipsJointSpace1925: philips,
      TvConnectionProtocol.rokuEcp8060: roku,
      TvConnectionProtocol.vidaaSmart36669: vidaa,
      TvConnectionProtocol.sonyBraviaIrcc: sony,
      TvConnectionProtocol.upnpDlnaControl: upnp,
      TvConnectionProtocol.irBlasterHardware: ir,
    };
  }

  late final Map<TvConnectionProtocol, TvRemoteDriver> _drivers;
  late final ArcelikGrundigDriver arcelikDriver;
  late final SamsungTizenDriver samsungDriver;
  late final LgWebOsDriver lgDriver;
  late final RokuEcpDriver rokuDriver;
  late final IrBlasterDriver irBlasterDriver;
  late final PhilipsJointSpaceDriver philipsDriver;
  late final VidaaSmartDriver vidaaDriver;

  TvRemoteDriver? driverFor(TvConnectionProtocol protocol) => _drivers[protocol];

  bool supportsCapability(TvDevice device, TvCapability cap) {
    final driver = _drivers[device.protocol];
    return driver?.capabilities.contains(cap) ?? false;
  }

  void dispose() {
    for (final driver in _drivers.values) {
      driver.dispose();
    }
  }
}
