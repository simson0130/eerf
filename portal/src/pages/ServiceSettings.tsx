import { useEffect, useState } from "react";
import { getServices, getWafRules, updateServiceMetadata, updateWafExcludeRules } from "../api";
import Spinner from "../components/Spinner";

interface ServiceMeta {
  service_key: string;
  fqdn: string;
  account_id: string;
  criticality: string;
  owner: string;
  service_name: string;
  business_hours: string;
  source: string;
  fo_waf_switch: boolean;
  fo_sg_attach: boolean;
}

interface WafRule {
  name: string;
  mode: string;
  excluded: boolean;
  priority: number;
}

type DirtyMap = Record<string, Partial<ServiceMeta>>;

export default function ServiceSettings() {
  const [services, setServices] = useState<ServiceMeta[]>([]);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [dirty, setDirty] = useState<DirtyMap>({});
  const [toast, setToast] = useState<string | null>(null);
  const [wafModal, setWafModal] = useState<{ serviceKey: string; fqdn: string } | null>(null);
  const [wafRules, setWafRules] = useState<WafRule[]>([]);
  const [wafLoading, setWafLoading] = useState(false);
  const [wafDirty, setWafDirty] = useState<Record<string, boolean>>({});

  const load = () => {
    setLoading(true);
    getServices().then((data) => {
      const svcs = (data.services || []).map((s: any) => ({
        service_key: s.service_key,
        fqdn: s.fqdn,
        account_id: s.account_id,
        criticality: s.service_metadata?.criticality || "",
        owner: s.service_metadata?.owner || "",
        service_name: s.service_metadata?.service_name || "",
        business_hours: s.service_metadata?.business_hours || "",
        source: s.service_metadata?.source || "none",
        fo_waf_switch: s.fo_options?.waf_switch !== false,
        fo_sg_attach: s.fo_options?.sg_attach !== false,
      }));
      setServices(svcs);
      setDirty({});
    }).finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, []);

  const updateLocal = (serviceKey: string, field: string, value: string) => {
    setDirty((prev) => ({
      ...prev,
      [serviceKey]: { ...prev[serviceKey], [field]: value },
    }));
  };

  const getVal = (svc: ServiceMeta, field: keyof ServiceMeta): string => {
    const val = dirty[svc.service_key]?.[field] ?? svc[field] ?? "";
    return String(val);
  };

  const hasDirty = Object.keys(dirty).length > 0;
  const dirtyCount = Object.values(dirty).reduce((sum, d) => sum + Object.keys(d).length, 0);

  const openWafModal = async (serviceKey: string, fqdn: string) => {
    setWafModal({ serviceKey, fqdn });
    setWafLoading(true);
    try {
      const data = await getWafRules(serviceKey);
      setWafRules(data.rules || []);
      const initial: Record<string, boolean> = {};
      (data.rules || []).forEach((r) => { initial[r.name] = r.excluded; });
      setWafDirty(initial);
    } catch {
      setWafRules([]);
      setWafDirty({});
    } finally {
      setWafLoading(false);
    }
  };

  const toggleWafExclude = (ruleName: string) => {
    setWafDirty((prev) => ({ ...prev, [ruleName]: !prev[ruleName] }));
  };

  const saveWafExcludes = async () => {
    if (!wafModal) return;
    const excluded = Object.entries(wafDirty).filter(([, v]) => v).map(([k]) => k);
    try {
      await updateWafExcludeRules(wafModal.serviceKey, excluded);
      setToast("WAF \uc608\uc678 \uaddc\uce59 \uc800\uc7a5 \uc644\ub8cc");
      setTimeout(() => setToast(null), 3000);
      setWafModal(null);
    } catch (e) {
      alert(`WAF \uaddc\uce59 \uc800\uc7a5 \uc2e4\ud328: ${e}`);
    }
  };

  const handleSave = async () => {
    setSaving(true);
    try {
      const entries = Object.entries(dirty);
      let successCount = 0;
      for (const [serviceKey, fields] of entries) {
        const payload: Record<string, string> = {};
        for (const [k, v] of Object.entries(fields)) {
          if (v !== undefined && v !== "") payload[k] = v as string;
        }
        if (Object.keys(payload).length > 0) {
          await updateServiceMetadata(serviceKey, payload);
          successCount++;
        }
      }
      setDirty({});
      setToast(`${successCount}\uac1c \uc11c\ube44\uc2a4 \uc800\uc7a5 \uc644\ub8cc`);
      setTimeout(() => setToast(null), 3000);
      load();
    } catch (e) {
      alert(`\uc800\uc7a5 \uc2e4\ud328: ${e}`);
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <Spinner />;

  const nullCount = services.reduce((acc, s) => {
    const crit = getVal(s, "criticality");
    const own = getVal(s, "owner");
    return acc + (crit ? 0 : 1) + (own ? 0 : 1);
  }, 0);

  return (
    <div className="space-y-6 pb-10">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-black text-gray-900 tracking-tight">\uc11c\ube44\uc2a4 \uc124\uc815</h1>
          <p className="text-sm text-gray-400 mt-0.5">\uc11c\ube44\uc2a4 \uba54\ud0c0\ub370\uc774\ud130 \uad00\ub9ac \u2014 Recovery Policy \u00b7 Risk \ud3c9\uac00 \uae30\ucd08 \ub370\uc774\ud130</p>
        </div>
        <button
          onClick={handleSave}
          disabled={!hasDirty || saving}
          className={`px-5 py-2.5 rounded-lg text-sm font-bold shadow transition ${
            hasDirty
              ? "bg-blue-600 text-white hover:bg-blue-700"
              : "bg-gray-200 text-gray-400 cursor-not-allowed"
          }`}
        >
          {saving ? "\uc800\uc7a5 \uc911..." : `\uc800\uc7a5${hasDirty ? ` (${dirtyCount})` : ""}`}
        </button>
      </div>

      {nullCount > 0 && (
        <div className="p-4 bg-amber-50 border border-amber-200 rounded-xl flex items-center gap-3">
          <span className="text-lg">\u26a0\ufe0f</span>
          <div>
            <p className="text-xs font-bold text-amber-800">\ubbf8\uc124\uc815 \ud56d\ubaa9 {nullCount}\uac74</p>
            <p className="text-[10px] text-amber-700 mt-0.5">Criticality / Owner\uac00 \uc124\uc815\ub418\uc9c0 \uc54a\uc740 \uc11c\ube44\uc2a4\uac00 \uc788\uc2b5\ub2c8\ub2e4. \uc815\ucc45 \ud310\ub2e8\uc5d0 \ud65c\uc6a9\ub429\ub2c8\ub2e4.</p>
          </div>
        </div>
      )}

      <div className="rounded-xl border border-gray-200 bg-white shadow-sm overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-gray-50 border-b border-gray-100">
            <tr>
              <th className="px-4 py-3 text-left text-[10px] font-bold text-gray-500 uppercase">\uc11c\ube44\uc2a4</th>
              <th className="px-4 py-3 text-left text-[10px] font-bold text-gray-500 uppercase">Criticality</th>
              <th className="px-4 py-3 text-left text-[10px] font-bold text-gray-500 uppercase">Owner</th>
              <th className="px-4 py-3 text-left text-[10px] font-bold text-gray-500 uppercase">\uc6b4\uc601 \uc2dc\uac04</th>
              <th className="px-4 py-3 text-left text-[10px] font-bold text-gray-500 uppercase">Source</th>
              <th className="px-4 py-3 text-left text-[10px] font-bold text-gray-500 uppercase">FO \uc635\uc158</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-50">
            {services.map((svc) => {
              const isDirty = !!dirty[svc.service_key];
              return (
                <tr key={svc.service_key} className={`hover:bg-gray-50/50 ${isDirty ? "bg-blue-50/30" : ""}`}>
                  <td className="px-4 py-3">
                    <div className="font-semibold text-gray-900 text-xs">{svc.fqdn}</div>
                    <div className="text-[10px] text-gray-400 font-mono">{svc.service_key}</div>
                  </td>
                  <td className="px-4 py-3">
                    <select
                      value={getVal(svc, "criticality")}
                      onChange={(e) => updateLocal(svc.service_key, "criticality", e.target.value)}
                      className={`px-2 py-1 rounded border text-xs ${
                        !getVal(svc, "criticality") ? "border-amber-300 bg-amber-50" : "border-gray-200"
                      }`}
                    >
                      <option value="">\ubbf8\uc124\uc815</option>
                      <option value="tier1">Tier 1 (Critical)</option>
                      <option value="tier2">Tier 2 (Standard)</option>
                      <option value="tier3">Tier 3 (Low)</option>
                    </select>
                  </td>
                  <td className="px-4 py-3">
                    <input
                      type="text"
                      value={getVal(svc, "owner")}
                      onChange={(e) => updateLocal(svc.service_key, "owner", e.target.value)}
                      placeholder="\ub2f4\ub2f9\ud300"
                      className={`px-2 py-1 rounded border text-xs w-28 ${
                        !getVal(svc, "owner") ? "border-amber-300 bg-amber-50" : "border-gray-200"
                      }`}
                    />
                  </td>
                  <td className="px-4 py-3">
                    <select
                      value={getVal(svc, "business_hours")}
                      onChange={(e) => updateLocal(svc.service_key, "business_hours", e.target.value)}
                      className="px-2 py-1 rounded border border-gray-200 text-xs"
                    >
                      <option value="">\ubbf8\uc124\uc815</option>
                      <option value="24x7">24x7</option>
                      <option value="business">\uc5c5\ubb34\uc2dc\uac04 (09-18)</option>
                      <option value="extended">\ud655\uc7a5 (07-22)</option>
                    </select>
                  </td>
                  <td className="px-4 py-3">
                    <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${
                      svc.source === "tag" ? "bg-blue-100 text-blue-700" :
                      svc.source === "manual" ? "bg-purple-100 text-purple-700" :
                      "bg-gray-100 text-gray-400"
                    }`}>{svc.source === "none" ? "\ubbf8\uc218\uc9d1" : svc.source}</span>
                  </td>
                  <td className="px-4 py-3">
                    <div className="flex items-center gap-3">
                      <label className="flex items-center gap-1 text-[10px]">
                        <input
                          type="checkbox"
                          checked={dirty[svc.service_key]?.fo_waf_switch !== undefined ? String(dirty[svc.service_key].fo_waf_switch) === "true" : svc.fo_waf_switch}
                          onChange={(e) => updateLocal(svc.service_key, "fo_waf_switch", e.target.checked ? "true" : "false")}
                          className="rounded border-gray-300"
                        />
                        <span className="text-gray-600">WAF</span>
                      </label>
                      <label className="flex items-center gap-1 text-[10px]">
                        <input
                          type="checkbox"
                          checked={dirty[svc.service_key]?.fo_sg_attach !== undefined ? String(dirty[svc.service_key].fo_sg_attach) === "true" : svc.fo_sg_attach}
                          onChange={(e) => updateLocal(svc.service_key, "fo_sg_attach", e.target.checked ? "true" : "false")}
                          className="rounded border-gray-300"
                        />
                        <span className="text-gray-600">SG</span>
                      </label>
                      <button
                        onClick={() => openWafModal(svc.service_key, svc.fqdn)}
                        className="px-2 py-0.5 rounded border border-gray-300 text-[9px] text-gray-500 hover:bg-gray-100 hover:text-gray-700 transition"
                        title="WAF \uc608\uc678\uaddc\uce59 \ud3b8\uc9d1"
                      >
                        \uc608\uc678\uaddc\uce59
                      </button>
                    </div>
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      {toast && (
        <div className="fixed bottom-4 right-4 bg-green-600 text-white px-4 py-2 rounded-lg text-xs font-bold shadow-lg">
          \u2705 {toast}
        </div>
      )}

      {/* WAF Exclude Rules Modal */}
      {wafModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/40">
          <div className="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 overflow-hidden">
            <div className="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
              <div>
                <h3 className="text-lg font-bold text-gray-900">WAF \uc608\uc678\uaddc\uce59 \ud3b8\uc9d1</h3>
                <p className="text-xs text-gray-400 mt-0.5">{wafModal.fqdn}</p>
              </div>
              <button onClick={() => setWafModal(null)} className="text-gray-400 hover:text-gray-600 text-xl">&times;</button>
            </div>
            <div className="px-6 py-4 max-h-96 overflow-y-auto">
              {wafLoading ? (
                <div className="flex justify-center py-8"><Spinner /></div>
              ) : wafRules.length === 0 ? (
                <p className="text-sm text-gray-400 py-4">WAF \uaddc\uce59\uc744 \ubd88\ub7ec\uc62c \uc218 \uc5c6\uc2b5\ub2c8\ub2e4. WAF\uac00 \uc5f0\uacb0\ub418\uc9c0 \uc54a\uc558\uac70\ub098 \uc811\uadfc \uad8c\ud55c\uc774 \uc5c6\uc2b5\ub2c8\ub2e4.</p>
              ) : (
                <div className="space-y-1">
                  <p className="text-[10px] text-gray-500 mb-3">
                    FO \uc2dc COUNT\u2192BLOCK \uc804\ud658\uc5d0\uc11c <span className="font-bold text-amber-600">\uc81c\uc678</span>\ud560 \uaddc\uce59\uc744 \uc120\ud0dd\ud569\ub2c8\ub2e4.
                    \uccb4\ud06c\ub41c \uaddc\uce59\uc740 Failover \uc2dc\uc5d0\ub3c4 COUNT \ubaa8\ub4dc\ub97c \uc720\uc9c0\ud569\ub2c8\ub2e4.
                  </p>
                  {wafRules.map((rule) => (
                    <label
                      key={rule.name}
                      className={`flex items-center gap-3 px-3 py-2 rounded-lg cursor-pointer transition ${
                        wafDirty[rule.name] ? "bg-amber-50 border border-amber-200" : "hover:bg-gray-50 border border-transparent"
                      }`}
                    >
                      <input
                        type="checkbox"
                        checked={!!wafDirty[rule.name]}
                        onChange={() => toggleWafExclude(rule.name)}
                        className="rounded border-gray-300"
                      />
                      <div className="flex-1 min-w-0">
                        <span className="text-xs font-medium text-gray-800 block truncate">{rule.name}</span>
                        <span className="text-[9px] text-gray-400">Priority {rule.priority}</span>
                      </div>
                      <span className={`px-2 py-0.5 rounded text-[9px] font-bold ${
                        rule.mode === "Block" ? "bg-red-100 text-red-700" :
                        rule.mode === "Count" ? "bg-yellow-100 text-yellow-700" :
                        rule.mode === "Allow" ? "bg-green-100 text-green-700" :
                        "bg-gray-100 text-gray-500"
                      }`}>{rule.mode}</span>
                    </label>
                  ))}
                </div>
              )}
            </div>
            <div className="px-6 py-4 border-t border-gray-100 flex items-center justify-between">
              <span className="text-[10px] text-gray-400">
                {Object.values(wafDirty).filter(Boolean).length}\uac1c \uaddc\uce59 \uc81c\uc678 \uc124\uc815
              </span>
              <div className="flex gap-2">
                <button
                  onClick={() => setWafModal(null)}
                  className="px-4 py-2 rounded-lg text-xs text-gray-600 hover:bg-gray-100 transition"
                >
                  \ucde8\uc18c
                </button>
                <button
                  onClick={saveWafExcludes}
                  className="px-4 py-2 rounded-lg text-xs font-bold bg-blue-600 text-white hover:bg-blue-700 transition"
                >
                  \uc800\uc7a5
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
