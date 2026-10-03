// Under Two Skies — beta download page + R2-backed downloads.
// GET /            Thai download/instructions page
// GET /beta1/<f> or /beta2/<f> streams the file from the R2 bucket (Range supported)

const SITE = "https://undertwoskies-website-promote.undertwoskies-game.workers.dev";
const FILES = [
  { file: "UnderTwoSkies-Windows.zip", name: "Windows", system: "Windows 10 / 11 · x86_64", size: "284 MB", instructions: "แตกไฟล์ ZIP แล้วเปิด UnderTwoSkies.exe", note: `<details class="platform-help"><summary>หาก Windows เตือนก่อนเปิดเกม</summary><p>บิลด์เบตายังไม่ได้เซ็นชื่อดิจิทัล หากดาวน์โหลดจากหน้านี้และต้องการเล่น ให้เลือก <b>More info → Run anyway</b> ในหน้าต่าง “Windows protected your PC”</p></details>` },
  { file: "UnderTwoSkies-macOS.zip", name: "macOS", system: "Apple Silicon และ Intel · Universal", size: "306 MB", instructions: "แตกไฟล์ ZIP แล้วดับเบิลคลิกเปิดแอป", note: `<p class="platform-note">เซ็นชื่อด้วย Developer ID และผ่านการรับรองจาก Apple แล้ว</p>` },
  { file: "UnderTwoSkies-Linux.zip", name: "Linux", system: "Linux / Steam Deck · x86_64", size: "274 MB", instructions: "แตกไฟล์ ZIP แล้วเปิด UnderTwoSkies.x86_64", note: `<details class="platform-help"><summary>หากไฟล์ยังเปิดไม่ได้</summary><p>อนุญาตให้ไฟล์ทำงานเป็นโปรแกรมใน Properties → Permissions หรือใช้ <code>chmod +x UnderTwoSkies.x86_64</code> แล้วเปิดอีกครั้ง</p></details>` },
];

function page() {
  const downloads = FILES.map(({file, name, system, size, instructions, note}) => `<article class="platform">
    <h2>${name}</h2><p class="system">${system}</p>
    <a class="download" href="/beta2/${file}">ดาวน์โหลดสำหรับ ${name}<span aria-hidden="true">↓</span></a>
    <p class="file-size">ZIP · ${size}</p><p class="install">${instructions}</p>${note}
  </article>`).join("\n");
  return `<!doctype html>
<html lang="th"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="description" content="ดาวน์โหลด Under Two Skies เบตา 2 ฟรี สำหรับ Windows, macOS และ Linux พร้อมวิธีติดตั้งและส่งความคิดเห็น">
<meta name="theme-color" content="#101b21"><link rel="icon" href="/images/logo/under_two_skies_icon.png"><title>ดาวน์โหลดเบตา 2 — Under Two Skies</title>
<style>
@font-face{font-family:Kanit;src:url('/game/fonts/Kanit-Regular.ttf') format('truetype');font-weight:400;font-display:swap}
@font-face{font-family:Kanit;src:url('/game/fonts/Kanit-Medium.ttf') format('truetype');font-weight:500;font-display:swap}
@font-face{font-family:Kanit;src:url('/game/fonts/Kanit-SemiBold.ttf') format('truetype');font-weight:600 800;font-display:swap}
@font-face{font-family:Chakra;src:url('/game/fonts/ChakraPetch-Medium.ttf') format('truetype');font-weight:500;font-display:swap}

:root{color-scheme:dark;--paper:#101b21;--panel:#16252b;--ink:#f4efdf;--muted:#b8c3c3;--line:#ffffff24;--gold:#e8bf76;--green:var(--gold)}
*{box-sizing:border-box}body{margin:0;background:var(--paper);color:var(--ink);font-family:Kanit,system-ui,sans-serif;line-height:1.75;font-size:16px}a{color:var(--green);text-underline-offset:4px}a:hover{text-decoration-thickness:2px}a:focus-visible,summary:focus-visible{outline:3px solid var(--gold);outline-offset:5px}header,main,footer{max-width:1240px;margin:auto;padding-inline:48px}header{display:flex;align-items:center;justify-content:space-between;gap:20px;padding-block:9px;min-height:94px;border-bottom:1px solid var(--line)}.brand{display:flex;align-items:center;min-height:44px}.brand img{display:block;width:144px;height:auto}.back{display:inline-flex;align-items:center;min-height:44px}.back{font-size:14px}main{padding-block:50px 36px}.intro{max-width:740px}.eyebrow{font-family:Chakra,Kanit,sans-serif;display:flex;align-items:center;gap:12px;color:var(--muted);font-size:14px;margin:0 0 16px}.version{color:var(--gold);border:1px solid var(--line);border-radius:0;padding:2px 9px;background:var(--panel)}h1{font-weight:500;font-size:clamp(30px,4vw,46px);line-height:1.3;letter-spacing:-1px;margin:0 0 15px}h2{font-weight:500;font-size:23px;line-height:1.45;margin:0 0 14px}.platform h2{font-family:Chakra,Kanit,sans-serif;font-weight:500;font-size:25px;margin:0}p{margin:0 0 14px}.lead{font-size:19px}.context{color:var(--muted);margin-bottom:30px}.platforms{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:18px}.platform{background:var(--panel);border:1px solid var(--line);border-radius:0;padding:24px;min-width:0}.system{color:var(--muted);font-size:13px;min-height:46px;margin:4px 0 16px}.download{display:flex;justify-content:space-between;gap:8px;align-items:center;background:var(--green);color:#18252b;padding:14px 20px;border-radius:0;font-weight:500;text-decoration:none;font-size:15px;min-height:48px}.download:hover{background:#f4d395;color:#101b21}.file-size{color:var(--muted);font-size:13px;margin:9px 0 17px}.install{font-size:15px}.platform-note,.platform-help{font-size:13px;color:var(--muted);margin:0}.platform-help p{margin:10px 0 0}.checksums{font-size:13px;color:var(--muted);margin:18px 0 0}.lower{display:grid;grid-template-columns:1.1fr 1fr;gap:64px;margin-top:42px;padding-top:32px;border-top:1px solid var(--line)}ol{padding-left:23px;margin:0 0 18px}li{padding-left:5px;margin-bottom:10px}.feedback-link{font-weight:500}.fine{font-size:14px;color:var(--muted)}.notes{border-top:1px solid var(--line);margin-top:24px;padding-top:18px}summary{cursor:pointer;color:var(--green);font-weight:600}details p{margin:12px 0 0}.notes ul{padding-left:20px;font-size:14px}code{font-size:.85em;background:#0b151b;padding:2px 5px;border-radius:3px;overflow-wrap:anywhere}kbd{font:inherit;font-size:.85em;border:1px solid var(--line);border-bottom-width:2px;border-radius:4px;padding:1px 5px;background:var(--panel)}footer{display:flex;justify-content:space-between;gap:20px;padding-block:22px 30px;border-top:1px solid var(--line);font-size:13px;color:var(--muted)}.skip{color:var(--ink);position:absolute;left:16px;top:-100px;background:var(--panel);padding:10px;z-index:1}.skip:focus{top:10px}
@media(max-width:780px){.brand img{width:128px}header,main,footer{padding-inline:20px}main{padding-top:32px}.platforms{grid-template-columns:1fr}.system{min-height:0}.platform{padding:22px}.lower{grid-template-columns:1fr;gap:30px;margin-top:30px}footer{flex-direction:column;gap:8px}.context{font-size:14px}}
</style></head><body>
<a class="skip" href="#main">ข้ามไปดาวน์โหลด</a>
<header><a class="brand" href="${SITE}/th/" aria-label="Under Two Skies"><img src="/images/logo/header-logo.png" width="1856" height="968" alt=""></a><a class="back" href="${SITE}/th/">← กลับเว็บไซต์เกม</a></header>
<main id="main"><section class="intro" aria-labelledby="title">
<p class="eyebrow"><span class="version">เบตา 2 · 0.2.0</span><span>3 ตุลาคม 2026</span></p>
<h1 id="title">ดาวน์โหลด แล้วมาลองเล่นกัน</h1>
<p class="lead">ไร่หมุนเวียนใต้เงาดาวเทียม — เบตาภาษาไทย<br>ดาวน์โหลดฟรี ไม่ต้องสมัครสมาชิก</p>
<p class="context">สำหรับคอมพิวเตอร์ · ใช้เมาส์และคีย์บอร์ด หรือจอยเกม · เล่นหนึ่งแปลงประมาณ 9 นาที</p>
</section>
<section aria-label="เลือกดาวน์โหลดตามระบบของคุณ"><div class="platforms">${downloads}</div>
<p class="checksums">ต้องการตรวจสอบไฟล์? <a href="/beta2/SHA256SUMS.txt">ดู SHA-256 ของทั้งสามไฟล์</a></p></section>
<div class="lower"><section aria-labelledby="feedback"><h2 id="feedback">เล่นจบแล้ว ช่วยเล่าให้เราฟัง</h2>
<p>เข้าใจเป้าหมายใน 5 นาทีแรกไหม? ติดตรงไหน?<br>ความคิดเห็นของคุณช่วยปรับเกมรอบถัดไป</p>
<ol><li>ในเกม ไปที่ <b>ตั้งค่า → เปิดโฟลเดอร์บันทึกการเล่น</b></li><li>เก็บไฟล์ <code>playtest_log.csv</code> แล้วส่งพร้อมความคิดเห็นในช่อง <b>#feedback</b></li></ol>
<a class="feedback-link" href="https://discord.gg/ZJ2ywpJ7Ss">ส่งความคิดเห็นใน Discord →</a>
<p class="fine" style="margin-top:12px">หากต้องการรายงาน FPS เปิดเครื่องมือทดสอบในตั้งค่า แล้วกด F3</p></section>
<section aria-labelledby="before"><h2 id="before">ก่อนเริ่มเล่น</h2>
<p>นี่คือบิลด์ทดสอบ เรายังรับฟังความคิดเห็นและปรับปรุงเกมอยู่</p>
<p class="fine">ออกจากเกม: Mac <kbd>⌘W</kbd> / <kbd>⌘Q</kbd> · Windows / Linux <kbd>Alt+F4</kbd><br>กลับมาเล่นจากบันทึกล่าสุดได้ หากออกระหว่างเผา จะเริ่มใหม่จากบันทึกก่อนเผา</p>
<details class="notes"><summary>มีอะไรใหม่ในเบตา 2</summary><ul><li>หมู่บ้านสามมิติ และท่าทางตัวละครกับเรนเจอร์ดีขึ้น</li><li>เสียง ดนตรี และบรรยากาศใหม่</li><li>เห็นมูนอฉีดน้ำชัดขึ้น พร้อมป้ายเติมน้ำและคำอธิบายลมหายใจ</li><li>ลดเสียงเตือนลูกไฟซ้ำ</li></ul></details>
<details class="notes"><summary>กระดานคะแนนออนไลน์</summary><p class="fine">ปิดเป็นค่าเริ่มต้น เปิดได้ใน <b>ตั้งค่า → กระดานออนไลน์</b> ส่งชื่อที่ใช้บนกระดานและคะแนน ลบคะแนนตัวเองได้ทุกเมื่อ</p></details>
</section></div></main>
<footer><span>Under Two Skies · เบตาภาษาไทย</span><a href="${SITE}/th/">อ่านเรื่องราวและดูภาพจากเกม →</a></footer>
</body></html>`;
}

export default {
	async fetch(req, env) {
		const url = new URL(req.url);
		if (url.pathname === "/")
			return new Response(page(), { headers: { "Content-Type": "text/html; charset=utf-8" } });
		if (!/^\/beta[12]\//.test(url.pathname))
			return new Response("not found", { status: 404 });
		if (req.method !== "GET" && req.method !== "HEAD")
			return new Response("method not allowed", { status: 405 });
		const key = decodeURIComponent(url.pathname.slice(1));
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
