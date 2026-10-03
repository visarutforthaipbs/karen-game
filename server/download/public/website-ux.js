// Device hints are advisory; they never download or hide platform choices.
const mobile = /Android|iPhone|iPad|iPod/i.test(navigator.userAgent) || (/Macintosh/i.test(navigator.userAgent) && navigator.maxTouchPoints > 1);
const platform = mobile ? null : /Windows/i.test(navigator.userAgent) ? 'Windows' : /Mac/i.test(navigator.userAgent) ? 'macOS' : /Linux/i.test(navigator.userAgent) ? 'Linux' : null;
for (const note of document.querySelectorAll('[data-device-note]')) {
  if (mobile && note.dataset.mobile) note.textContent = note.dataset.mobile;
}
if (platform) for (const card of document.querySelectorAll('[data-platform]')) {
  if (card.dataset.platform === platform) { card.classList.add('suggested'); const hint=card.querySelector('[data-suggested]'); if(hint) hint.hidden=false; }
}
for (const button of document.querySelectorAll('[data-copy-feedback]')) button.addEventListener('click', async () => {
  const box=button.closest('.feedback-template'); const text=box.querySelector('textarea'); const status=box.querySelector('[data-copy-status]');
  try { await navigator.clipboard.writeText(text.value); status.textContent=button.dataset.success; }
  catch { text.focus(); text.select(); status.textContent=button.dataset.fallback; }
});
