from decimal import Decimal as D
hourly = (D("0.0001867") + 4*D("0.000018") + 16*D("0.000002")) * 3600
tput = D("336.4")            # débit total à saturation, palier 16 (raw/step2-c16.txt)
p_in, p_out = D("0.30"), D("2.50")
alerts, t_in, t_out = D(87216), D(800), D(150)
cost_m = lambda occ: hourly / (tput*3600*occ) * 1_000_000
api_alert = (t_in*p_in + t_out*p_out) / 1_000_000
api_day = alerts * api_alert
gpu_day = hourly * 24
switch = gpu_day / api_alert
req = alerts * t_out / 86400
out = {
 "hourly": hourly, "cost_per_M_100": cost_m(D(1)), "cost_per_M_20": cost_m(D("0.2")),
 "api_alert": api_alert, "api_day": api_day, "gpu_day": gpu_day, "switch": switch,
 "required_tps": req, "measured_tps": tput, "margin": tput/req,
 "gpu_per_M_out_100": cost_m(D(1)), "api_out": p_out,
 "occupancy_mean": req/tput,
}
for k,v in out.items(): print(f"{k} = {v:.6f}")
