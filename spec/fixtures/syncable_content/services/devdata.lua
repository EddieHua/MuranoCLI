--#EVENT device2 data_in
-- luacheck: globals data (magic variable from Murano)

-- Get the timestamp for this data if a record action.
-- Otherwise use default (now)
local stamped = nil
if data.api == "record" then
  stamped = tostring(data.value[1]) .. 's'
end

-- Save it to timeseries database.
Tsdb.write{
	tags = {sn=data.device_sn},
	metrics = {[data.alias] = tonumber(data.value[2])},
	ts = stamped
}

-- vim: set et ai sw=2 ts=2 :
