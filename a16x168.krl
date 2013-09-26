ruleset a16x168 {
  meta {
    name "ISY Service"
    description <<
CloudOS Service for Universal Device ISY 99i
>>
    author "Phil Windley"
    logging on

    use module a169x676 alias pds
    use module a169x701 alias CloudRain

    provides control_node

  }

  dispatch {
  }

  global {

    get_config_value = function (name) {
      pds:get_setting_data_value(meta:rid(), name);
    };

    get_base_url = function() {
        ip_addr = get_config_value("isy_ip_addr") || '127.0.0.1';
        port = get_config_value("isy_port") || '80';
        
        "http://"+ip_addr+ ":" + port + "/rest"
    }   

    control_node = defaction(node_id, command) {
      isy_url = get_base_url() + "/nodes/#{node_id}/cmd/#{command}";
      //isy_url = "http://requestb.in/s1qagus1";
      http:get(isy_url) with
        credentials = {"username": get_config_value("isy_username"),
	               "password": get_config_value("isy_password"),
		       "realm": "/",
                       "netloc": get_config_value("isy_ip_addr")+":"+get_config_value("isy_port")
                      }
    }

    lights = "1A%20F3%203E%201";
    heater = "20%20B9%208F%201";

  }

  rule battery {
    select when office battery_low
    pre {
      msg = <<
The device #{event:attr("device_type")}:#{event:attr("device_id")} in the #{event:attr("location")} at #{get_config_value("location")} has a low battery. Change it soon. 
>>;
    }
    send_directive("noop");
    fired {
      raise notification event status with
        priority = 0 and	 
        application = meta:rulesetName() and
        subject = "Low battery" and
        description = msg
    }
  }

  rule lights {
    select when explicit office_lights
    pre {
      state = event:attr("state") eq "on" => "DON" | "DOF";
    }
    control_node(lights, state);
  }


  rule heater {
    select when explicit office_heater
    pre {
      state = event:attr("state") eq "on" => "DON" | "DOF";
    }
    control_node(heater, state);
  }


  //----------------------------------- display ----------------------------------------------------


  // ----------------------------------- configuration setup ---------------------------------------
  rule load_app_config_settings {
    select when web sessionLoaded
    pre {
      schema = [
        {
          "name"     : "location",
          "label"    : "Location",
          "dtype"    : "text"
        },
        {
          "name"     : "isy_ip_addr",
          "label"    : "ISY Hub IP Address",
          "dtype"    : "text"
        },
        {
          "name"     : "isy_port",
          "label"    : "ISY IP Port",
          "dtype"    : "text"
        },
        {
          "name"     : "isy_username",
          "label"    : "ISY Username",
          "dtype"    : "text"
        },
        {
          "name"     : "isy_password",
          "label"    : "ISY Password",
          "dtype"    : "text"
        }
      ];
      data = {
	"location" : "Kynetx",
        "isy_ip_addr"  : "127.0.0.1",
	"isy_port" : "",
	"isy_username" : "none",
	"isy_password" : "none"
      };
    }
    always {
      raise pds event new_settings_schema
        with setName   = meta:rulesetName()
        and  setRID    = meta:rid()
        and  setSchema = schema
        and  setData   = data
        and  _api = "sky";
    }
  }


}
