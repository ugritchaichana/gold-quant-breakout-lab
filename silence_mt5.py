import time
import sys
from pycaw.pycaw import AudioUtilities, ISimpleAudioVolume

def mute_mt5():
    try:
        sessions = AudioUtilities.GetAllSessions()
        for s in sessions:
            proc = s.Process
            name = proc.name() if proc else ''
            if name.lower() in ['terminal64.exe', 'terminal.exe', 'metatester64.exe']:
                vol = s._ctl.QueryInterface(ISimpleAudioVolume)
                if not vol.GetMute() or vol.GetMasterVolume() > 0.0:
                    vol.SetMasterVolume(0.0, None)
                    vol.SetMute(1, None)
                    print(f"[{time.strftime('%X')}] Muted {name} (PID: {proc.pid})")
    except Exception as e:
        pass

if __name__ == '__main__':
    print("MT5 Audio Silencer Watchdog started.")
    mute_mt5()
    while True:
        mute_mt5()
        time.sleep(2)
