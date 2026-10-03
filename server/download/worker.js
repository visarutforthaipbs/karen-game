// Under Two Skies — beta download page + R2-backed downloads.
// GET /            Thai download/instructions page
// GET /beta1/<f>, /beta2/<f> or /beta3/<f> streams versioned R2 files (Range supported)

const SITE = "https://undertwoskies-website-promote.undertwoskies-game.workers.dev";
function page(lang = "th") {
  const t = (th, en) => lang === "en" ? en : th;
  const home = SITE + (lang === "en" ? "/" : "/th/");
  const files = [
    {file:"UnderTwoSkies-Windows.zip",name:"Windows",system:"Windows 10 / 11 · x86_64",size:"276 MB",instructions:t("แตกไฟล์ ZIP แล้วเปิด UnderTwoSkies.exe","Extract the ZIP, then open UnderTwoSkies.exe."),note:`<details class="platform-help"><summary>${t("หาก Windows เตือนก่อนเปิดเกม","If Windows warns before opening")}</summary><p>${t("บิลด์เบตายังไม่ได้เซ็นชื่อดิจิทัล หากดาวน์โหลดจากหน้านี้และต้องการเล่น ให้เลือก","This beta is unsigned. If you downloaded it here and want to play, choose")} <b>More info → Run anyway</b> ${t("ในหน้าต่าง","in the")} “Windows protected your PC” ${t("","prompt.")}</p></details>`},
    {file:"UnderTwoSkies-macOS.zip",name:"macOS",system:"Apple Silicon / Intel · Universal",size:"298 MB",instructions:t("แตกไฟล์ ZIP แล้วดับเบิลคลิกเปิดแอป","Extract the ZIP, then double-click the app."),note:`<p class="platform-note">${t("เซ็นชื่อด้วย Developer ID และผ่านการรับรองจาก Apple แล้ว","Developer ID signed and notarized by Apple.")}</p>`},
    {file:"UnderTwoSkies-Linux.zip",name:"Linux",system:"Linux / Steam Deck · x86_64",size:"266 MB",instructions:t("แตกไฟล์ ZIP แล้วเปิด UnderTwoSkies.x86_64","Extract the ZIP, then open UnderTwoSkies.x86_64."),note:`<p class="platform-note">${t("บิลด์ Linux / Steam Deck ยังไม่ผ่านการทดสอบ","Linux / Steam Deck builds are untested.")}</p><details class="platform-help"><summary>${t("หากไฟล์ยังเปิดไม่ได้","If the file does not open")}</summary><p>${t("อนุญาตให้ไฟล์ทำงานเป็นโปรแกรมใน Properties → Permissions หรือใช้","Allow execution in Properties → Permissions, or run")} <code>chmod +x UnderTwoSkies.x86_64</code></p></details>`},
  ];
  const downloads = files.map(({file,name,system,size,instructions,note}) => `<article class="platform" data-platform="${name}">
    <h2>${name}</h2><p class="system">${system}</p>
    <span class="suggestion" data-suggested hidden>${t("แนะนำตามอุปกรณ์ที่เปิดเว็บ","Suggested for this device")}</span>
    <a class="download" href="/beta3/${file}">${t("ดาวน์โหลดสำหรับ","Download for")} ${name}<span aria-hidden="true">↓</span></a>
    <p class="file-size">ZIP · ${size}</p><p class="install">${instructions}</p>${note}
  </article>`).join("\n");
  return `<!doctype html>
<html lang="${lang}"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="${t("ดาวน์โหลด Under Two Skies เบตา 3 ฟรี สำหรับ Windows, macOS และ Linux พร้อมวิธีติดตั้งและส่งความคิดเห็น","Download the free Under Two Skies beta 3 for Windows, macOS and Linux, with installation and feedback instructions.")}">
<meta name="theme-color" content="#101b21"><link rel="icon" href="/images/logo/under_two_skies_icon.png"><title>${t("ดาวน์โหลดเบตา 3 — Under Two Skies","Download beta 3 — Under Two Skies")}</title>
<style>
@font-face{font-family:Kanit;src:url('/game/fonts/Kanit-Regular.ttf') format('truetype');font-weight:400;font-display:swap}
@font-face{font-family:Kanit;src:url('/game/fonts/Kanit-Medium.ttf') format('truetype');font-weight:500;font-display:swap}
@font-face{font-family:Kanit;src:url('/game/fonts/Kanit-SemiBold.ttf') format('truetype');font-weight:600 800;font-display:swap}
@font-face{font-family:Chakra;src:url('/game/fonts/ChakraPetch-Medium.ttf') format('truetype');font-weight:500;font-display:swap}

:root{color-scheme:dark;--paper:#101b21;--panel:#16252b;--ink:#f4efdf;--muted:#b8c3c3;--line:#ffffff24;--gold:#e8bf76;--green:var(--gold)}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:Kanit,system-ui,sans-serif;line-height:1.75;font-size:16px}a{color:var(--green);text-underline-offset:4px}a:hover{text-decoration-thickness:2px}a:focus-visible,summary:focus-visible{outline:3px solid var(--gold);outline-offset:5px}header,main,footer{max-width:1240px;margin:auto;padding-inline:48px}header{display:flex;align-items:center;justify-content:space-between;gap:20px;padding-block:9px;min-height:94px;border-bottom:1px solid var(--line)}.brand{display:flex;align-items:center;min-height:44px}.brand img{display:block;width:144px;height:auto}.back{display:inline-flex;align-items:center;min-height:44px}.back{font-size:14px}main{padding-block:50px 36px}.intro{max-width:740px}.eyebrow{font-family:Chakra,Kanit,sans-serif;display:flex;align-items:center;gap:12px;color:var(--muted);font-size:14px;margin:0 0 16px}.version{color:var(--gold);border:1px solid var(--line);border-radius:0;padding:2px 9px;background:var(--panel)}h1{font-weight:500;font-size:clamp(30px,4vw,46px);line-height:1.3;letter-spacing:-1px;margin:0 0 15px}h2{font-weight:500;font-size:23px;line-height:1.45;margin:0 0 14px}.platform h2{font-family:Chakra,Kanit,sans-serif;font-weight:500;font-size:25px;margin:0}p{margin:0 0 14px}.lead{font-size:19px}.context{color:var(--muted);margin-bottom:30px}.platforms{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}.platform{background:var(--panel);border:1px solid var(--line);border-radius:0;padding:24px;min-width:0}.system{color:var(--muted);font-size:13px;min-height:46px;margin:4px 0 16px}.download{display:flex;justify-content:space-between;gap:8px;align-items:center;background:var(--green);color:#18252b;padding:14px 20px;border-radius:0;font-weight:500;text-decoration:none;font-size:15px;min-height:48px}.download:hover{background:#f4d395;color:#101b21}.file-size{color:var(--muted);font-size:13px;margin:9px 0 17px}.install{font-size:15px}.platform-note,.platform-help{font-size:13px;color:var(--muted);margin:0}.platform-help p{margin:10px 0 0}.checksums{font-size:13px;color:var(--muted);margin:18px 0 0}.lower{display:grid;grid-template-columns:1.1fr 1fr;gap:64px;margin-top:42px;padding-top:32px;border-top:1px solid var(--line)}ol{padding-left:23px;margin:0 0 18px}li{padding-left:5px;margin-bottom:10px}.feedback-link{font-weight:500}.fine{font-size:14px;color:var(--muted)}.notes{border-top:1px solid var(--line);margin-top:24px;padding-top:18px}summary{cursor:pointer;color:var(--green);font-weight:600}details p{margin:12px 0 0}.notes ul{padding-left:20px;font-size:14px}code{font-size:.85em;background:#0b151b;padding:2px 5px;border-radius:3px;overflow-wrap:anywhere}kbd{font:inherit;font-size:.85em;border:1px solid var(--line);border-bottom-width:2px;border-radius:4px;padding:1px 5px;background:var(--panel)}footer{display:flex;justify-content:space-between;gap:20px;padding-block:22px 30px;border-top:1px solid var(--line);font-size:13px;color:var(--muted)}.skip{color:var(--ink);position:absolute;left:16px;top:-100px;background:var(--panel);padding:10px;z-index:1}.skip:focus{top:10px}
@media(max-width:780px){.brand img{width:128px}header,main,footer{padding-inline:20px}main{padding-top:32px}.platforms{grid-template-columns:1fr}.system{min-height:0}.platform{padding:22px}.lower{grid-template-columns:1fr;gap:30px;margin-top:30px}footer{flex-direction:column;gap:8px}.context{font-size:14px}}
.languages{white-space:nowrap;font-size:14px}.languages a{display:inline-flex;align-items:center;justify-content:center;min-width:44px;min-height:44px;color:var(--muted)}.languages a[aria-current="page"]{color:var(--gold)}.back{margin-left:auto}.suggestion{display:block;min-height:22px;font-size:12px;color:var(--gold);margin-bottom:10px}.suggestion[hidden]{display:block;visibility:hidden}.platform.suggested{border-color:var(--gold)}.feedback-template textarea{width:100%;font:inherit;font-size:14px;line-height:1.6;color:var(--ink);background:var(--paper);border:1px solid var(--line);padding:12px;margin-block:12px;resize:vertical}.copy-feedback{font:inherit;color:var(--gold);background:transparent;border:1px solid var(--line);padding:10px 16px;min-height:44px;cursor:pointer}.copy-feedback:focus-visible,textarea:focus-visible{outline:3px solid var(--gold);outline-offset:4px}.feedback-template [data-copy-status]{margin-top:12px}@media(max-width:600px){header{flex-wrap:wrap;gap:8px 12px}.back{order:3;width:100%;margin-left:0}.languages{margin-left:auto}}
</style></head><body>
<a class="skip" href="#main">${t("ข้ามไปดาวน์โหลด","Skip to downloads")}</a>
<header><a class="brand" href="${home}" aria-label="Under Two Skies"><img src="/images/logo/header-logo.png" width="1856" height="968" alt=""></a><a class="back" href="${home}">${t("← กลับเว็บไซต์เกม","← Back to the game website")}</a><nav class="languages" aria-label="${t("ภาษาเว็บไซต์","Website language")}"><a href="/en/" lang="en" aria-current="${lang === "en" ? "page" : "false"}">EN</a><span aria-hidden="true"> / </span><a href="/" lang="th" aria-current="${lang === "th" ? "page" : "false"}">ไทย</a></nav></header>
<main id="main"><section class="intro" aria-labelledby="title">
<p class="eyebrow"><span class="version">${t("เบตา 3 · 0.3.0","Beta 3 · 0.3.0")}</span><span>${t("3 ตุลาคม 2026","3 October 2026")}</span></p>
<h1 id="title">${t("ดาวน์โหลด แล้วมาลองเล่นกัน","Download and try a season.")}</h1>
<p class="lead">${t("ไร่หมุนเวียนใต้เงาดาวเทียม — เบตาภาษาไทย / อังกฤษ","Rotational Farming in the Shadow of the Satellite — Thai / English beta")}<br>${t("ดาวน์โหลดฟรี ไม่ต้องสมัครสมาชิก","Free download. No account needed.")}</p>
<p class="context">${t("สำหรับคอมพิวเตอร์ · ใช้เมาส์และคีย์บอร์ด หรือจอยเกม · เล่นหนึ่งแปลงประมาณ 9 นาที","Computer required · mouse and keyboard or gamepad · about 9 minutes per plot")}</p>
<p class="fine" data-device-note data-mobile="${t("เปิดจากมือถือหรือแท็บเล็ต? ตัวเกมต้องเล่นบนคอมพิวเตอร์ เก็บลิงก์นี้ไว้เปิดบนเครื่องได้","On a phone or tablet? The game needs a computer. Keep this link to open there.")}">${t("ตัวเกม: ไทย / อังกฤษ · เปลี่ยนภาษาได้ในตั้งค่า → ภาษา / Language","Game: Thai / English. Switch in Settings → Language; Thai is the default.")}</p></section>
<section aria-label="${t("เลือกดาวน์โหลดตามระบบของคุณ","Choose your platform")}"><div class="platforms">${downloads}</div>
<p class="checksums">${t("ต้องการตรวจสอบไฟล์?","Want to verify your download?")} <a href="/beta3/SHA256SUMS.txt">${t("ดู SHA-256 ของทั้งสามไฟล์","View SHA-256 checksums for all three files")}</a></p></section>
<div class="lower"><section aria-labelledby="feedback"><h2 id="feedback">${t("เล่นจบแล้ว ช่วยเล่าให้เราฟัง","Played a season? Tell us about it.")}</h2>
<p>${t("เข้าใจเป้าหมายใน 5 นาทีแรกไหม? ติดตรงไหน?","Did the goal make sense in the first five minutes? Where did you get stuck?")}<br>${t("ความคิดเห็นของคุณช่วยปรับเกมรอบถัดไป","Your feedback helps improve the next build.")}</p>
<ol><li>${t("ในเกม ไปที่","In the game, go to")} <b>${t("ตั้งค่า → เปิดโฟลเดอร์บันทึกการเล่น","Settings → Open playtest log folder")}</b></li><li>${t("เก็บไฟล์","Keep")} <code>playtest_log.csv</code> ${t("แล้วส่งพร้อมความคิดเห็นในช่อง","and post it with your comments in")} <b>#feedback</b></li></ol>
<a class="feedback-link" href="https://discord.gg/ZJ2ywpJ7Ss">${t("ส่งความคิดเห็นใน Discord →","Send feedback in Discord →")}</a>
<details class="feedback-template notes"><summary>${t("แบบฟอร์มความคิดเห็นสั้น ๆ","A short feedback template")}</summary>
<p class="fine">${t("คัดลอก เติมข้อมูลที่ทราบ แล้วส่งใน Discord ช่อง #feedback","Copy, fill in what you know, and post in Discord #feedback.")}</p>
<textarea readonly rows="7" aria-label="${t("แบบฟอร์มความคิดเห็น","Feedback template")}">${t("บิลด์: เบตา 3 (0.3.0)\nภาษาในเกม: ไทย / อังกฤษ\nคอมพิวเตอร์ / ระบบปฏิบัติการ:\nกำลังทำอะไรอยู่:\nสิ่งที่เกิดขึ้น:\nสิ่งที่คาดว่าจะเกิด:\nภาพหน้าจอ / playtest_log.csv (ถ้ามี):","Build: beta 3 (0.3.0)\nGame language: Thai / English\nComputer / OS:\nWhat I was doing:\nWhat happened:\nWhat I expected:\nScreenshot / playtest_log.csv (if available):")}</textarea>
<button type="button" class="copy-feedback" data-copy-feedback data-success="${t("คัดลอกแล้ว — วางใน Discord ได้เลย","Copied — paste it in Discord.")}" data-fallback="${t("เลือกข้อความด้านบนแล้วคัดลอกได้เลย","Select the text above and copy it manually.")}">${t("คัดลอกแบบฟอร์ม","Copy template")}</button><p class="fine" role="status" aria-live="polite" data-copy-status></p></details>
<p class="fine" style="margin-top:12px">${t("หากต้องการรายงาน FPS เปิดเครื่องมือทดสอบในตั้งค่า แล้วกด F3","To report FPS, enable playtest tools in Settings, then press F3.")}</p></section>
<section aria-labelledby="before"><h2 id="before">${t("ก่อนเริ่มเล่น","Before you play")}</h2>
<p>${t("นี่คือบิลด์ทดสอบ เรายังรับฟังความคิดเห็นและปรับปรุงเกมอยู่","This is a test build. We are still gathering feedback and improving the game.")}</p>
<p class="fine">${t("ออกจากเกม: Mac","Quit: Mac")} <kbd>⌘W</kbd> / <kbd>⌘Q</kbd> · Windows / Linux <kbd>Alt+F4</kbd><br>${t("กลับมาเล่นจากบันทึกล่าสุดได้ หากออกระหว่างเผา จะเริ่มใหม่จากบันทึกก่อนเผา","Resume from your latest save. Leaving during a burn restarts from the pre-burn save.")}</p>
<p class="fine">${t("สเปก GPU/RAM ขั้นต่ำและเวอร์ชัน macOS ที่รองรับยังอยู่ระหว่างการวัดผล จึงยังไม่รับรองประสิทธิภาพบนทุกเครื่อง","Minimum GPU/RAM and macOS version requirements are still being measured. Performance on every computer is not yet confirmed.")}</p>
<details class="notes"><summary>${t("มีอะไรใหม่ในเบตา 3","What changed in beta 3")}</summary><ul><li>${t("เลือกภาษาไทย / อังกฤษ ทั้งข้อความ คำบรรยาย และเสียงพูดได้ในตั้งค่า","Choose Thai / English text, subtitles and recorded speech in Settings")}</li><li>${t("ภาพยนตร์สั้นอธิบายไร่หมุนเวียนและแนวกันไฟเมื่อเริ่มเกมครั้งแรก หยุด ข้าม และดูซ้ำในวิธีเล่นได้","First-time context film explains rotational farming and firebreaks; pause, skip or replay from How to play")}</li><li>${t("เสียงพูดใหม่ ดนตรีและบรรยากาศในภาพยนตร์สั้น","Updated voices plus music and ambience in the opening film")}</li><li>${t("ปรับเมนูและการใช้จอยให้สอดคล้องกัน พร้อมแก้การกู้คืนบันทึกและผลเผาค้างจากเกมก่อน","Consistent menus and controller focus, improved save recovery and clean new-campaign summaries")}</li></ul></details>
<details class="notes"><summary>${t("กระดานคะแนนออนไลน์","Online scoreboard")}</summary><p class="fine">${t("ปิดเป็นค่าเริ่มต้น เปิดได้ใน","Off by default. Enable it in")} <b>${t("ตั้งค่า → กระดานออนไลน์","Settings → Online scoreboard")}</b> ${t("ส่งชื่อที่ใช้บนกระดานและคะแนน ลบคะแนนตัวเองได้ทุกเมื่อ","Sends your scoreboard name and score. You can delete your score at any time.")}</p></details>
</section></div></main>
<footer><span>${t("Under Two Skies · เบตาภาษาไทย / อังกฤษ","Under Two Skies · Thai / English beta")}</span><a href="${home}">${t("อ่านเรื่องราวและดูภาพจากเกม →","Explore the story and game images →")}</a></footer>
<script src="/website-ux.js" defer></script></body></html>`;
}

export default {
	async fetch(req, env) {
		const url = new URL(req.url);
		if (["/", "/en/", "/en", "/th/", "/th"].includes(url.pathname))
			return new Response(page(url.pathname.startsWith("/en") ? "en" : "th"), { headers: { "Content-Type": "text/html; charset=utf-8" } });
		if (!/^\/beta[123]\//.test(url.pathname))
			return new Response("not found", { status: 404 });
		if (req.method !== "GET" && req.method !== "HEAD")
			return new Response("method not allowed", { status: 405 });
		let key;
		try { key = decodeURIComponent(url.pathname.slice(1)); }
		catch { return new Response("invalid path", { status: 400 }); }
		const wantsRange = req.headers.has("Range");
		const object = await env.BUCKET.get(key, wantsRange ? { range: req.headers, onlyIf: req.headers } : { onlyIf: req.headers });
		if (object === null)
			return new Response("not found", { status: 404 });
		const headers = new Headers();
		object.writeHttpMetadata(headers);
		headers.set("etag", object.httpEtag);
		headers.set("Accept-Ranges", "bytes");
		if (!key.endsWith(".txt"))
			headers.set("Content-Disposition", `attachment; filename="${key.split("/").pop()}"`);
		const partial = wantsRange && object.range && "offset" in object.range;
		if (partial) {
			const end = object.range.offset + object.range.length - 1;
			headers.set("Content-Range", `bytes ${object.range.offset}-${end}/${object.size}`);
		} else {
			headers.set("Content-Length", String(object.size));
		}
		const hasBody = "body" in object && object.body;
		const status = hasBody ? (partial ? 206 : 200) : 304;
		return new Response(req.method === "HEAD" ? null : (hasBody ? object.body : null), { status, headers });
	},
};
