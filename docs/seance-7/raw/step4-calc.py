# Recalcul de l'étape 3 avec les tokens mesurés dans la trace de l'étape 4 (médiane de 5 alertes).
from decimal import Decimal as D
hourly = (D("0.0001867") + 4*D("0.000018") + 16*D("0.000002")) * 3600
tput = D("336.4")                      # débit total à saturation, raw/step2-c16.txt
p_in, p_out = D("0.30"), D("2.50")     # API Vertex AI, endpoint global
alerts, t_in, t_out = D(87216), D(576), D(67)
prefill_tps = D("2876")                # llamacpp:prompt_tokens_seconds, raw/step2-metrics.txt
api_alert = (t_in*p_in + t_out*p_out) / 1_000_000
api_day, gpu_day = alerts*api_alert, hourly*24
switch = gpu_day / api_alert
req = alerts * t_out / 86400
sec_per_alert = t_in/prefill_tps + t_out/tput       # lecture du prompt + génération
cap_day = 86400 / sec_per_alert
out = {
 "api_alert": api_alert, "api_day": api_day, "gpu_day": gpu_day, "ecart_jour": api_day-gpu_day,
 "ecart_relatif_pct": (api_day-gpu_day)/api_day*100, "switch": switch, "switch_vs_volume": alerts/switch,
 "required_tps": req, "occ_sortie": req/tput,
 "gpu_per_M_out_occ": hourly/(tput*3600*(req/tput))*1_000_000,
 "sec_per_alert": sec_per_alert, "cap_alertes_jour": cap_day, "occ_avec_prefill": alerts/cap_day,
 "api_day_regional(+10%)": alerts*(t_in*D("0.33")+t_out*D("2.75"))/1_000_000,
}
for k, v in out.items(): print(f"{k} = {v:.6f}")
