// Under Two Skies — beta download page + R2-backed downloads.
// GET /            Thai download/instructions page
// GET /beta1/<f>   streams the file from the R2 bucket (Range supported)

const FILES = [
	["UnderTwoSkies-Windows.zip", "Windows 10/11 (x86_64)", "199 MB"],
	["UnderTwoSkies-macOS.zip", "macOS (Universal) · ผ่านการรับรองจาก Apple", "230 MB"],
	["UnderTwoSkies-Linux.zip", "Linux / Steam Deck (x86_64)", "189 MB"],
];

const PAGE = `<!doctype html>
<html lang="th"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Under Two Skies — เบตา 1</title>
<style>
	body{background:#101318;color:#e8e2d4;font-family:system-ui,'Kanit',sans-serif;margin:0;padding:24px 16px;line-height:1.6}
	main{max-width:720px;margin:0 auto}
	h1{color:#e8b54a;margin:0 0 4px;font-size:1.6rem}
	.sub{color:#9aa08f;margin:0 0 20px}
	a{color:#e8b54a}
	.dl{display:block;background:#1b2027;border:1px solid #2c3440;border-radius:10px;padding:14px 16px;margin:10px 0;text-decoration:none}
	.dl b{color:#e8e2d4}
	.dl span{color:#9aa08f;font-size:.9rem}
	.card{background:#161b22;border:1px solid #2c3440;border-radius:10px;padding:14px 16px;margin:18px 0;font-size:.95rem}
	code{background:#0c0f13;padding:2px 6px;border-radius:6px;font-size:.85rem}
	h2{font-size:1.05rem;color:#cfe3cf;margin:0 0 8px}
</style></head><body><main>
<h1>Under Two Skies <small>เบตา 1</small></h1>
<p class="sub">ไร่หมุนเวียนใต้เงาดาวเทียม · เบตาภาษาไทย ดาวน์โหลดฟรี ไม่ต้องสมัครสมาชิก</p>
<p>เกมสำหรับ <b>PC เท่านั้น</b> (ใช้เมาส์+คีย์บอร์ด หรือจอยเกม) · เกมเป็นภาษาไทย · เล่นหนึ่งแปลงใช้เวลา ~9 นาที</p>
%LINKS%
<p><a href="/beta1/SHA256SUMS.txt">SHA256SUMS.txt</a> สำหรับตรวจสอบไฟล์</p>
<div class="card"><h2>Windows ขึ้นจอฟ้า "Windows protected your PC"?</h2>
กด <b>More info</b> แล้ว <b>Run anyway</b> — บิลด์เบตายังไม่ได้เซ็นชื่อดิจิทัล</div>
<div class="card"><h2>macOS</h2>
แอปเซ็นชื่อด้วย Developer ID และผ่านการตรวจรับรอง (notarized) จาก Apple แล้ว แตกไฟล์ zip แล้วดับเบิลคลิกเปิดได้เลย</div>
<div class="card"><h2>หลังเล่นจบ ช่วยส่งผลให้เราหน่อย</h2>
ในเกม: <b>ตั้งค่า → เปิดโฟลเดอร์บันทึกการเล่น</b> เก็บไฟล์ <code>playtest_log.csv</code> ไว้ ส่งไฟล์และความคิดเห็นได้ที่ดิสคอร์ด ช่อง <b>#feedback</b>: <a href="https://discord.gg/ZJ2ywpJ7Ss">discord.gg/ZJ2ywpJ7Ss</a>
ช่วยจดสั้น ๆ ด้วยว่า เข้าใจเป้าหมายใน 5 นาทีแรกไหม ติดตรงไหน และ FPS (กด F3 เมื่อเปิดเครื่องมือทดสอบในตั้งค่า)</div>
<div class="card"><h2>กระดานออนไลน์ (เบตา)</h2>
ปิดเป็นค่าเริ่มต้น เปิดได้ใน <b>ตั้งค่า → กระดานออนไลน์</b> ส่งเฉพาะชื่อบนกระดานและคะแนน ไม่มีข้อมูลส่วนตัว ลบคะแนนตัวเองได้ทุกเมื่อ</div>
<p class="sub">ข้อมูลเกม: <a href="https://undertwoskies-website-promote.undertwoskies-game.workers.dev/th/">เว็บไซต์ Under Two Skies</a></p>
</main></body></html>`;

function page() {
	const links = FILES.map(([f, label, size]) =>
		`<a class="dl" href="/beta1/${f}"><b>${label}</b><br><span>${f} · ${size}</span></a>`).join("\n");
	return PAGE.replace("%LINKS%", links);
}

export default {
	async fetch(req, env) {
		const url = new URL(req.url);
		if (url.pathname === "/")
			return new Response(page(), { headers: { "Content-Type": "text/html; charset=utf-8" } });
		if (!url.pathname.startsWith("/beta1/"))
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
