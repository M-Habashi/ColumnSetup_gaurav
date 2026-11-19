const paths={
 info:'<circle cx="12" cy="12" r="8.5"/><path d="M12 11v5m0-9v.2"/>',
 ar:'<path d="M2.5 9.5 4 6.7h16l1.5 2.8v6.2l-2 1.6h-4.2l-2.8-3h-1l-2.8 3H4.5l-2-1.6z"/><path d="m5.5 10 2-.5m9 .5h2"/>',
 layers:'<path d="m3 8 9-5 9 5-9 5zM3 12l9 5 9-5M3 16l9 5 9-5"/>',
 down:'<path d="m6 9 6 6 6-6"/>',up:'<path d="m6 15 6-6 6 6"/>',
 fullscreen:'<path d="M3 9V3h6m6 0h6v6m0 6v6h-6m-6 0H3v-6"/>',
 expand:'<path d="M13 4h7v7m0-7-7 7M4 13v7h7m-7 0 7-7"/>',
 orbit:'<ellipse cx="12" cy="12" rx="10" ry="5" transform="rotate(-30 12 12)"/><circle cx="12" cy="12" r="2"/><path d="m4 11-2-1 .6-2"/>',
 walk:'<circle cx="13" cy="4" r="1.8"/><path d="m8.5 21 3-7 3 3 1 4m-8-9 2-4 3-1 2 4 3 1m-5-5-1 7"/>',
 home:'<path d="M4 10.5a8 8 0 1 1 .5 5M4 4v6.5h6.5"/>',
 cube:'<path d="m3.5 7.3 8.5-4.8 8.5 4.8v9.4L12 21.5l-8.5-4.8zm0 0 8.5 5 8.5-5M12 12.3v9"/>',
 frame:'<path d="M3.5 21V4h17v17M3.5 10h17m-17 6h17M9.2 4v17m5.6-17v17"/>',
 path:'<path d="M3 3v17h18M5 15c3 4 13 1 12-5s-11-4-10 1 10 5 11-3"/><circle cx="18" cy="7" r="1.6"/>',
 camera:'<rect x="2.5" y="6" width="13.5" height="12" rx="2"/><path d="m16 10 5-3v10l-5-3"/>',
 flag:'<path d="M5 21V3m0 1c5-4 8 4 14 0v9c-6 4-9-4-14 0"/>',
 play:'<path d="M6 3.6c0-.7.5-.9 1.1-.5l13 8.2c.6.4.6 1 0 1.4l-13 8.2c-.6.4-1.1.2-1.1-.5z"/>',
 pause:'<path d="M5.8 4h4.4v16H5.8zm8 0h4.4v16h-4.4z"/>',
 speed:'<path d="M3 17a9 9 0 1 1 18 0M12 14l5-6"/><circle cx="12" cy="14" r="1.4"/>',
 close:'<path d="m5 5 14 14M19 5 5 19"/>'
};
export function icon(name){return '<svg class="ic" viewBox="0 0 24 24" aria-hidden="true">'+paths[name]+'</svg>';}
export function installIcons(){for(const el of document.querySelectorAll('i[data-icon]'))el.innerHTML=icon(el.dataset.icon);}
