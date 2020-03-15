{ config, pkgs, lib, ... }:
with lib;
let
  cfg = config.services.auto-shutdown;
in
{
  options = {
    services.auto-shutdown = {
      enable = mkEnableOption "Auto Shutdown without SSH activity";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.shutdown-no-activity = let
        scriptFile = ''
    #!/usr/bin/env bash

    if [[ -z $(netstat | grep ssh | grep ESTABLISHED) ]]
    then
      if [[ -e $RUNTIME_DIRECTORY/first ]]
      then
        systemctl poweroff
      else
        touch $RUNTIME_DIRECTORY/first
      fi
    else
      [[ -e $RUNTIME_DIRECTORY/first ]] && rm $RUNTIME_DIRECTORY/first
    fi
    exit 0
        '';
    in
    {
      path = [ pkgs.bash pkgs.nettools ];
      environment.SHELL = "${pkgs.bash}/bin/bash";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${pkgs.writeText "shutdown.sh" scriptFile}";
        RuntimeDirectoryPreserve="yes";
        RuntimeDirectory="auto-shutdown";
      };
    };

    systemd.timers.shutdown-no-activity = {
      description = "shutdown after no activity";
      wantedBy = [ "timers.target" ];
      partOf = [ "shutdown-no-activity.service" ];
      timerConfig = {
        OnCalendar = "hourly";
      };
    };
  };
}
