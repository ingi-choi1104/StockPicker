const { onSchedule } = require('firebase-functions/v2/scheduler');
const { onRequest } = require('firebase-functions/v2/https');
const { initializeApp } = require('firebase-admin/app');
const { getFirestore, Timestamp } = require('firebase-admin/firestore');
const axios = require('axios');
const cheerio = require('cheerio');
const iconv = require('iconv-lite');

initializeApp();
const db = getFirestore();
const COLLECTION = 'events';

// ─────────────────────────────────────────────
// 공통 유틸
// ─────────────────────────────────────────────

const DEFAULT_HEADERS = {
  'User-Agent': 'Mozilla/5.0 (Linux; Android 10; SM-G973F) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36',
  'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
  'Accept-Language': 'ko-KR,ko;q=0.9',
};

const JSON_HEADERS = {
  ...DEFAULT_HEADERS,
  'Accept': 'application/json, text/javascript, */*; q=0.01',
  'X-Requested-With': 'XMLHttpRequest',
};

function parseDate(raw) {
  if (!raw) return null;
  const cleaned = String(raw).replace(/[^\d]/g, '');
  if (cleaned.length < 8) return null;
  const y = parseInt(cleaned.slice(0, 4));
  const m = parseInt(cleaned.slice(4, 6)) - 1;
  const d = parseInt(cleaned.slice(6, 8));
  const dt = new Date(y, m, d);
  return isNaN(dt.getTime()) ? null : dt;
}

function guessCategory(title) {
  if (/ISA/.test(title)) return 'EventCategory.isa';
  if (/IRP|퇴직연금/.test(title)) return 'EventCategory.irp';
  if (/개인연금|연금저축/.test(title)) return 'EventCategory.pension';
  if (/환율|환전|외화|달러|엔화|위안/.test(title)) return 'EventCategory.exchange';
  if (/수수료|할인|우대/.test(title)) return 'EventCategory.feeDiscount';
  if (/신규|계좌/.test(title)) return 'EventCategory.newAccount';
  if (/추천|친구|지인/.test(title)) return 'EventCategory.referral';
  if (/적립|포인트|리워드|캐시백/.test(title)) return 'EventCategory.reward';
  if (/매매|거래|선물|옵션|ETF|주식|투자/.test(title)) return 'EventCategory.trading';
  return 'EventCategory.other';
}

async function httpGet(url, headers = DEFAULT_HEADERS) {
  console.log(`[GET] ${url}`);
  const res = await axios.get(url, { headers, timeout: 15000, responseType: 'arraybuffer' });

  // Content-Type에서 charset 감지
  const contentType = (res.headers['content-type'] || '').toLowerCase();
  const isEucKr = contentType.includes('euc-kr') || contentType.includes('ks_c_5601');
  const decoded = iconv.decode(Buffer.from(res.data), isEucKr ? 'euc-kr' : 'utf-8');

  console.log(`[GET] ${url} → status=${res.status}, charset=${isEucKr ? 'euc-kr' : 'utf-8'}, length=${decoded.length}`);
  return decoded;
}

async function httpGetJson(url, headers = JSON_HEADERS) {
  console.log(`[GET-JSON] ${url}`);
  const res = await axios.get(url, { headers, timeout: 15000 });
  console.log(`[GET-JSON] ${url} → status=${res.status}`);
  return res.data;
}

async function httpPost(url, body, headers = DEFAULT_HEADERS) {
  const res = await axios.post(url, body, {
    headers: { ...headers, 'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8' },
    timeout: 10000,
  });
  return res.data;
}


// ─────────────────────────────────────────────
// 증권사별 스크래퍼
// ─────────────────────────────────────────────

/** 삼성증권: GET JSON API */
async function scrapeSamsung() {
  const BASE = 'https://www.samsungpop.com';
  const events = [];
  try {
    const refererHeaders = { ...JSON_HEADERS, Referer: `${BASE}/mbw/customer/noticeEvent.do?cmd=eventList` };
    const json = await httpGetJson(
      `${BASE}/mbw/customer/noticeEvent.do?cmd=getEventList&pageNo=1&pageSize=50`,
      refererHeaders
    );
    const total = json.totalCount || 0;
    const allItems = [...(json.list || [])];
    console.log(`[Samsung] total=${total}, page1 items=${allItems.length}`);

    const totalPages = Math.ceil(total / 50);
    for (let p = 2; p <= Math.min(totalPages, 20); p++) {
      const pageJson = await httpGetJson(
        `${BASE}/mbw/customer/noticeEvent.do?cmd=getEventList&pageNo=${p}&pageSize=50`,
        refererHeaders
      );
      allItems.push(...(pageJson.list || []));
    }

    for (const item of allItems) {
      const title = (item.ntcTitle1 || '').trim();
      if (!title) continue;

      // period: "2026-03-03 ~ 2026-04-17"
      const periodStr = item.period || '';
      const dates = [...periodStr.matchAll(/\d{4}-\d{2}-\d{2}/g)].map(m => m[0]);
      const startDate = parseDate(dates[0]);
      const endDate = dates[1] ? parseDate(dates[1]) : null;

      const imgFileNm = item.ImgFileNm || '';
      const imageUrl = imgFileNm
        ? `${BASE}/common.do?cmd=down&saveKey=event.file&fileName=${imgFileNm}&inlineYn=N`
        : null;

      const menuSeqNo = item.menuSeqNo || '';
      const eventUrl = menuSeqNo
        ? `${BASE}/mbw/customer/noticeEvent.do?cmd=ingView&menuSeqNo=${menuSeqNo}`
        : null;

      // HTML 태그 제거
      const descHtml = item.EtcConts5 || item.Etcconts1 || title;
      const $ = cheerio.load(descHtml);
      const description = $.text().trim().slice(0, 300) || title;

      events.push({
        id: `samsung_${menuSeqNo}`,
        title,
        description,
        brokerage: 'BrokerageType.samsung',
        category: guessCategory(title),
        startDate: startDate ? Timestamp.fromDate(startDate) : Timestamp.now(),
        endDate: endDate ? Timestamp.fromDate(endDate) : null,
        eventUrl,
        imageUrl,
        benefits: [],
        createdAt: Timestamp.now(),
      });
    }
  } catch (e) {
    console.error('Samsung scrape error:', e.message);
  }
  return events;
}

/** 미래에셋증권: SSR HTML
 *  구조: <li><a href="javascript:doView('ID','1','')">이벤트 제목</a></li>
 *  제목 = a 태그 텍스트, 날짜 = 없거나 alt에 포함
 */
async function scrapeMiraeAsset() {
  const BASE = 'https://securities.miraeasset.com';
  const events = [];
  const seenIds = new Set();

  for (let page = 1; page <= 5; page++) {
    try {
      const url = page === 1
        ? `${BASE}/hki/hki7000/r05.do`
        : `${BASE}/hki/hki7000/r05.do?currentPage=${page}`;
      const html = await httpGet(url);
      const $ = cheerio.load(html);

      // doView 링크를 가진 li 항목 수집
      const items = $('li').filter((_, el) =>
        $(el).find('a[href*="doView"]').length > 0
      );
      console.log(`[MiraeAsset] page=${page}, items found=${items.length}`);
      if (items.length > 0) {
        console.log(`[MiraeAsset] first item HTML: ${$.html(items.first()).slice(0, 600)}`);
      }
      if (items.length === 0) break;

      let newCount = 0;
      items.each((i, el) => {
        const link = $(el).find('a[href*="doView"]').first();
        const href = link.attr('href') || '';
        const idMatch = href.match(/doView\('([^']+)'/);
        const eventId = idMatch ? idMatch[1] : `p${page}_${i}`;

        if (seenIds.has(eventId)) return;
        seenIds.add(eventId);

        // 실제 구조: li.colSec > dl.eventCont > dd.evTit (제목), dd.evDate (날짜)
        const title = $(el).find('dd.evTit').text().trim()
          || $(el).find('dd.evtit, .evTit, .tit').text().trim();
        if (!title) return;

        const dateText = $(el).find('dd.evDate, dd.evdate, .evDate').text().trim();
        const dates = [...dateText.matchAll(/\d{4}[.\-]\d{2}[.\-]\d{2}/g)].map(m => m[0]);
        const startDate = parseDate(dates[0]);
        const endDate = dates[1] ? parseDate(dates[1]) : null;

        // 이미지: dt > a > img
        const img = $(el).find('dt img').first();
        const alt = img.attr('alt') || '';
        let imageUrl = img.attr('src') || null;
        if (imageUrl && !imageUrl.startsWith('http')) imageUrl = BASE + imageUrl;

        events.push({
          id: `miraeasset_${eventId}`,
          title,
          description: alt && alt !== title ? alt.replace(/\s*-\s*\d{4}.*/, '').trim() : title,
          brokerage: 'BrokerageType.miraeAsset',
          category: guessCategory(title),
          startDate: startDate ? Timestamp.fromDate(startDate) : Timestamp.now(),
          endDate: endDate ? Timestamp.fromDate(endDate) : null,
          eventUrl: `${BASE}/hki/hki7000/r05.do?cmd=doView&eventId=${eventId}`,
          imageUrl,
          benefits: [],
          createdAt: Timestamp.now(),
        });
        newCount++;
      });

      if (newCount === 0 || items.length < 5) break;
    } catch (e) {
      console.error(`MiraeAsset page ${page} error:`, e.message);
      break;
    }
  }
  return events;
}

/** 대신증권: SSR
 *  구조: 이벤트 하나에 두 개의 <a href="...cid=N"> 태그
 *    - 첫 번째 <a>: <img src="/attach/event_image/..."> 포함
 *    - 두 번째 <a>: 제목 텍스트
 *    - 형제 <p>들: 설명, 기간
 *  → cid별로 그룹핑하여 이미지+제목+날짜 조합
 */
async function scrapeDaeshin() {
  const BASE = 'https://www.daishin.com';
  const events = [];
  const seenCids = new Set();

  for (let page = 1; page <= 20; page++) {
    try {
      const url = page === 1
        ? `${BASE}/g.ds?m=1109&p=12931&v=12831`
        : `${BASE}/g.ds?m=1109&p=12931&v=12831&pageNo=${page}`;
      const html = await httpGet(url);
      const $ = cheerio.load(html);

      const eventMap = new Map();
      const allLinks = $('a[href*="eventDetail.ds"]');
      console.log(`[Daeshin] page=${page}, links=${allLinks.length}`);
      if (allLinks.length === 0) break;

      allLinks.each((_, el) => {
        const href = $(el).attr('href') || '';
        const cidMatch = href.match(/cid=(\d+)/);
        if (!cidMatch) return;
        const cid = cidMatch[1];
        if (seenCids.has(cid)) return;

        if (!eventMap.has(cid)) {
          eventMap.set(cid, { cid, href, imageUrl: null, title: '', parent: $(el).parent() });
        }
        const entry = eventMap.get(cid);

        const imgEl = $(el).find('img[src*="/attach/event_image/"]').first();
        if (imgEl.length > 0) {
          let src = imgEl.attr('src') || '';
          if (src && !src.startsWith('http')) src = BASE + src;
          entry.imageUrl = src;
        } else {
          const text = $(el).text().trim();
          if (text) entry.title = text;
        }
      });

      let newCount = 0;
      for (const [cid, entry] of eventMap) {
        if (!entry.title) continue;
        seenCids.add(cid);
        newCount++;

        const paras = entry.parent.find('p');
        const description = paras.eq(0).text().trim() || entry.title;
        const allParaText = paras.map((_, el) => $(el).text()).get().join(' ');
        const dates = [...allParaText.matchAll(/\d{4}\.\d{2}\.\d{2}/g)].map(m => m[0]);

        events.push({
          id: `daeshin_${cid}`,
          title: entry.title,
          description,
          brokerage: 'BrokerageType.daeshin',
          category: guessCategory(entry.title),
          startDate: parseDate(dates[0]) ? Timestamp.fromDate(parseDate(dates[0])) : Timestamp.now(),
          endDate: dates[1] && parseDate(dates[1]) ? Timestamp.fromDate(parseDate(dates[1])) : null,
          eventUrl: entry.href.startsWith('http') ? entry.href : BASE + entry.href,
          imageUrl: entry.imageUrl,
          benefits: [],
          createdAt: Timestamp.now(),
        });
      }

      if (newCount === 0) break;
    } catch (e) {
      console.error(`[Daeshin] page=${page} error:`, e.message);
      break;
    }
  }
  console.log(`[Daeshin] final events=${events.length}`);
  return events;
}

/** KB증권: SSR HTML
 *  구조: ul > li 각 항목에
 *    - <a href="/go.able?linkcd=s060902030000&seq=N..."><img></a>  (이미지 링크)
 *    - <div class="category">카테고리</div>
 *    - <a href="/go.able?...">제목</a>  (제목 링크)
 *    - <span class="period">기간</span>2026/03/01 ~ 2026/05/31
 */
async function scrapeKb() {
  const BASE = 'https://www.kbsec.com';
  const events = [];
  const seenIds = new Set();

  for (let page = 1; page <= 20; page++) {
    try {
      const url = page === 1
        ? `${BASE}/go.able?linkcd=m06090002`
        : `${BASE}/go.able?linkcd=m06090002&pageNo=${page}`;
      const html = await httpGet(url, { ...DEFAULT_HEADERS, Referer: `${BASE}/go.able` });
      const $ = cheerio.load(html);

      const items = $('li').filter((_, el) =>
        $(el).find('a[href*="seq="]').length > 0
      ).toArray();
      console.log(`[KB] page=${page}, items=${items.length}`);
      if (items.length === 0) break;

      let newCount = 0;
      items.forEach((el, i) => {
        const titleLink = $(el).find('a').filter((_, a) => $(a).find('img').length === 0).first();
        const title = titleLink.text().trim();
        if (!title) return;

        const href = titleLink.attr('href') || $(el).find('a').first().attr('href') || '';
        const seqMatch = href.match(/[?&]seq=(\d+)/);
        const eventId = seqMatch ? seqMatch[1] : `p${page}_${i}`;
        if (seenIds.has(eventId)) return;
        seenIds.add(eventId);
        newCount++;

        let dateText = '';
        $(el).find('span.period').each((_, span) => {
          dateText = $(span).parent().text().replace($(span).text(), '').trim();
        });
        const dates = [...dateText.matchAll(/\d{4}[/.\-]\d{2}[/.\-]\d{2}/g)].map(m => m[0]);

        let imageUrl = $(el).find('img').first().attr('src') || null;
        if (imageUrl && !imageUrl.startsWith('http')) imageUrl = BASE + imageUrl;
        const eventUrl = href ? (href.startsWith('http') ? href : BASE + href) : null;

        events.push({
          id: `kb_${eventId}`,
          title,
          description: title,
          brokerage: 'BrokerageType.kb',
          category: guessCategory(title),
          startDate: parseDate(dates[0]) ? Timestamp.fromDate(parseDate(dates[0])) : Timestamp.now(),
          endDate: dates[1] && parseDate(dates[1]) ? Timestamp.fromDate(parseDate(dates[1])) : null,
          eventUrl,
          imageUrl,
          benefits: [],
          createdAt: Timestamp.now(),
        });
      });

      if (newCount === 0) break;
    } catch (e) {
      console.error(`[KB] page=${page} error:`, e.message);
      break;
    }
  }
  console.log(`[KB] final events=${events.length}`);
  return events;
}

// ─────────────────────────────────────────────
// Puppeteer 기반 스크래퍼 (KB, 한국투자, 키움, 신한)
// ─────────────────────────────────────────────

function parseBrowserEvents(html, brokerage, idPrefix, baseUrl) {
  const $ = cheerio.load(html);
  const events = [];
  const seenIds = new Set();

  const selectors = [
    'ul.event_list > li', 'ul.evtList > li', 'ul.event-list > li',
    '.event_wrap li', '.evtListWrap li', '.event-list li',
    '.board_list tr', 'ul.list > li',
  ];

  let items = [];
  for (const sel of selectors) {
    const found = $(sel).toArray();
    if (found.length > 0) { items = found; break; }
  }

  // KB 스타일: seq= 파라미터가 있는 a를 포함한 li
  if (items.length === 0) {
    items = $('li').filter((_, el) => $(el).find('a[href*="seq="]').length > 0).toArray();
  }

  console.log(`[${idPrefix}] items=${items.length}, html_length=${html.length}`);
  if (items.length === 0) {
    // 디버그: 실제 HTML 구조 확인
    const bodySnippet = $('body').html() || html;
    console.log(`[${idPrefix}] body_sample=${bodySnippet.slice(0, 800)}`);
  }

  items.forEach((el, i) => {
    // 이미지 없는 a 태그가 제목
    const titleLink = $(el).find('a').filter((_, a) => $(a).find('img').length === 0).first();
    const title = titleLink.text().trim()
      || $(el).find('h3, h4, .tit, .title, strong').first().text().trim();
    if (!title) return;

    const href = titleLink.attr('href') || $(el).find('a').first().attr('href') || '';
    const idMatch = href.match(/[?&](?:seq|id|no|idx|evtNo|eventSeq)=(\d+)/);
    const eventId = idMatch ? idMatch[1] : `${i}`;
    if (seenIds.has(eventId)) return;
    seenIds.add(eventId);

    const dateText = $(el).find('.date, .period, span').text().trim();
    const dates = [...dateText.matchAll(/\d{4}[/.\-]\d{2}[/.\-]\d{2}/g)].map(m => m[0]);

    let imageUrl = $(el).find('img').first().attr('src') || null;
    if (imageUrl && !imageUrl.startsWith('http')) imageUrl = baseUrl + imageUrl;
    const eventUrl = href ? (href.startsWith('http') ? href : baseUrl + href) : null;

    events.push({
      id: `${idPrefix}_${eventId}`,
      title,
      description: title,
      brokerage,
      category: guessCategory(title),
      startDate: parseDate(dates[0]) ? Timestamp.fromDate(parseDate(dates[0])) : Timestamp.now(),
      endDate: dates[1] && parseDate(dates[1]) ? Timestamp.fromDate(parseDate(dates[1])) : null,
      eventUrl,
      imageUrl,
      benefits: [],
      createdAt: Timestamp.now(),
    });
  });
  return events;
}


/** 한국투자증권: SSR HTML
 *  Python 검증: ?gubun=i&cmd=TF04gb010001&currentPage=N&CUSTGUBUN=00
 *  총 페이지: div.pager 내 goPage('N') 패턴에서 최댓값 추출
 */
async function scrapeKoreaInvestment() {
  const BASE = 'https://securities.koreainvestment.com';
  const LIST_URL = `${BASE}/main/customer/notice/Event.jsp`;
  const DETAIL_BASE = `${BASE}/main/customer/notice/Event.jsp?gubun=i&cmd=TF04gb010002&num=`;
  const KI_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': BASE,
    'Accept-Language': 'ko-KR,ko;q=0.9',
  };
  const ID_RE = /doView\('(\d+)'\)/;
  const events = [];
  const seenIds = new Set();

  function parseEventsFromHtml($) {
    $('a').filter((_, el) => ID_RE.test($(el).attr('href') || '')).each((_, el) => {
      const match = ($(el).attr('href') || '').match(ID_RE);
      if (!match) return;
      const eventId = match[1];
      if (seenIds.has(eventId)) return;
      seenIds.add(eventId);

      const title = $(el).find('p.title').text().trim();
      if (!title) return;

      const description = $(el).find('p.con').text().trim();
      const dateText = $(el).find('span.letter_0').text().trim();
      const dates = [...dateText.matchAll(/(\d{4}\.\d{2}\.\d{2})/g)].map(m => m[0]);

      let imageUrl = $(el).find('img').first().attr('src') || null;
      if (imageUrl && !imageUrl.startsWith('http')) imageUrl = BASE + imageUrl;

      events.push({
        id: `koreainvest_${eventId}`,
        title,
        description: description || title,
        brokerage: 'BrokerageType.koreaInvestment',
        category: guessCategory(title),
        startDate: parseDate(dates[0]) ? Timestamp.fromDate(parseDate(dates[0])) : Timestamp.now(),
        endDate: dates[1] && parseDate(dates[1]) ? Timestamp.fromDate(parseDate(dates[1])) : null,
        eventUrl: `${DETAIL_BASE}${eventId}`,
        imageUrl,
        benefits: [],
        createdAt: Timestamp.now(),
      });
    });
  }

  try {
    // 1페이지 → 총 페이지 수 파악 (div.pager의 goPage('N') 최댓값)
    const html1 = await httpGet(
      `${LIST_URL}?gubun=i&cmd=TF04gb010001&currentPage=1&CUSTGUBUN=00`,
      KI_HEADERS
    );
    const $1 = cheerio.load(html1);
    parseEventsFromHtml($1);

    const pagerHtml = $1('div.pager').html() || '';
    const pageNums = [...pagerHtml.matchAll(/goPage\('(\d+)'\)/g)].map(m => parseInt(m[1]));
    const totalPages = pageNums.length > 0 ? Math.max(...pageNums) : 1;
    console.log(`[KoreaInvestment] totalPages=${totalPages}`);

    for (let page = 2; page <= totalPages; page++) {
      const html = await httpGet(
        `${LIST_URL}?gubun=i&cmd=TF04gb010001&currentPage=${page}&CUSTGUBUN=00`,
        KI_HEADERS
      );
      parseEventsFromHtml(cheerio.load(html));
    }
  } catch (e) {
    console.error('[KoreaInvestment] error:', e.message);
  }
  console.log(`[KoreaInvestment] final events=${events.length}`);
  return events;
}

/** NH투자증권: SSR HTML (EUC-KR, 세션 쿠키 필요)
 *  Python 검증: ul.wooriEventList > li, eventView('seq') onclick
 *  URL: https://www.nhsec.com/guestGuide/ctmList/eventIngList.action
 */
async function scrapeNh() {
  const BASE = 'https://www.nhsec.com';
  const ING_URL = `${BASE}/guestGuide/ctmList/eventIngList.action`;
  const VIEW_URL = `${BASE}/guestGuide/ctmList/eventIngView.action`;
  const NH_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': BASE + '/',
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'ko-KR,ko;q=0.9',
  };
  const PERIOD_RE = /이벤트기간\s*:\s*([\d.]+)\s*~\s*([\d.]+)/;
  const SEQ_RE = /eventView\('(\d+)'/;
  const events = [];

  try {
    // 쿠키 세션 획득
    const initRes = await axios.get(BASE, { headers: NH_HEADERS, timeout: 10000, responseType: 'arraybuffer' });
    const cookies = (initRes.headers['set-cookie'] || []).map(c => c.split(';')[0]).join('; ');
    const headers = { ...NH_HEADERS, ...(cookies ? { Cookie: cookies } : {}) };

    const fetchPage = async (pageNo) => {
      const params = pageNo > 1 ? `?pageNo=${pageNo}` : '';
      return httpGet(ING_URL + params, headers);
    };

    const parseItems = ($) => {
      $('ul.wooriEventList > li').each((_, li) => {
        const titleEl = $(li).find('.eventArea .subTitV strong');
        const title = titleEl.text().trim();
        if (!title) return;

        const descEl = $(li).find('.eventArea > a');
        const rawText = descEl.text().replace(/\s+/g, ' ').trim();
        const periodMatch = rawText.match(PERIOD_RE);
        const description = rawText.split('이벤트기간')[0].trim();

        const onclick = $(li).find('[onclick]').first().attr('onclick') || '';
        const seqMatch = onclick.match(SEQ_RE);
        const evtSeq = seqMatch ? seqMatch[1] : '';

        const imgEl = $(li).find('.bannerArea img');
        let imageUrl = imgEl.attr('src') || null;
        if (imageUrl && !imageUrl.startsWith('http')) imageUrl = BASE + imageUrl;

        events.push({
          id: `nh_${evtSeq || title.slice(0, 10)}`,
          title,
          description: description || title,
          brokerage: 'BrokerageType.nh',
          category: guessCategory(title),
          startDate: periodMatch ? Timestamp.fromDate(parseDate(periodMatch[1])) : Timestamp.now(),
          endDate: periodMatch && parseDate(periodMatch[2]) ? Timestamp.fromDate(parseDate(periodMatch[2])) : null,
          eventUrl: evtSeq ? `${VIEW_URL}?evt_seq=${evtSeq}` : ING_URL,
          imageUrl,
          benefits: [],
          createdAt: Timestamp.now(),
        });
      });
    };

    const html1 = await fetchPage(1);
    const $1 = cheerio.load(html1);
    parseItems($1);

    // 페이지네이션: div.paginationV 내 Paging(N) onclick
    const pagerHtml = $1('div.paginationV').html() || '';
    const pageNums = [...pagerHtml.matchAll(/Paging\((\d+)\)/g)].map(m => parseInt(m[1]));
    const totalPages = pageNums.length > 0 ? Math.max(...pageNums) : 1;

    for (let p = 2; p <= totalPages; p++) {
      const html = await fetchPage(p);
      parseItems(cheerio.load(html));
    }
  } catch (e) {
    console.error('[NH] error:', e.message);
  }
  console.log(`[NH] final events=${events.length}`);
  return events;
}

/** 하나증권: SSR HTML (UTF-8)
 *  Python 검증: a.btn-link[href*='bbsSeq'], img[alt]=제목, span.date=기간
 *  URL: https://www.hanaw.com/corebbs5/eventIng/list/list.cmd
 */
async function scrapeHana() {
  const BASE = 'https://www.hanaw.com';
  const EVENT_URL = `${BASE}/corebbs5/eventIng/list/list.cmd`;
  const HANA_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': BASE + '/',
    'Accept-Language': 'ko-KR,ko;q=0.9',
  };
  const events = [];
  const seenUrls = new Set();

  const parseItems = ($) => {
    $('a.btn-link[href*="bbsSeq"]').each((_, el) => {
      const img = $(el).find('img').first();
      let title = (img.attr('alt') || '').trim();
      if (!title) {
        title = $(el).find('span').filter((_, s) => /tit|title|subject/i.test($(s).attr('class') || '')).first().text().trim()
          || $(el).text().replace(/\s+/g, ' ').trim().slice(0, 60);
      }
      if (!title) return;

      const dateText = $(el).find('span.date').text().trim() || $(el).text();
      const dateMatch = dateText.match(/(\d{4}\.\d{2}\.\d{2})\s*~\s*(\d{4}\.\d{2}\.\d{2})/);

      let imageUrl = img.attr('src') || null;
      if (imageUrl && !imageUrl.startsWith('http')) imageUrl = BASE + imageUrl;

      const href = $(el).attr('href') || '';
      const eventUrl = href.startsWith('/') ? BASE + href : href;
      if (seenUrls.has(eventUrl)) return;
      seenUrls.add(eventUrl);

      events.push({
        id: `hana_${eventUrl.match(/bbsSeq=(\d+)/)?.[1] || title.slice(0, 10)}`,
        title,
        description: title,
        brokerage: 'BrokerageType.hana',
        category: guessCategory(title),
        startDate: dateMatch ? Timestamp.fromDate(parseDate(dateMatch[1])) : Timestamp.now(),
        endDate: dateMatch && parseDate(dateMatch[2]) ? Timestamp.fromDate(parseDate(dateMatch[2])) : null,
        eventUrl,
        imageUrl,
        benefits: [],
        createdAt: Timestamp.now(),
      });
    });
  };

  try {
    const html1 = await httpGet(EVENT_URL, HANA_HEADERS);
    const $1 = cheerio.load(html1);
    parseItems($1);

    // 페이지네이션: curPage=N 파라미터
    const pagerHtml = $1('[class*="pager"], [class*="pagination"], [class*="page"]').html() || '';
    const pageNums = [...pagerHtml.matchAll(/curPage=(\d+)/g)].map(m => parseInt(m[1]));
    const totalPages = pageNums.length > 0 ? Math.max(...pageNums) : 1;

    for (let p = 2; p <= totalPages; p++) {
      const html = await httpGet(`${EVENT_URL}?curPage=${p}`, HANA_HEADERS);
      parseItems(cheerio.load(html));
    }
  } catch (e) {
    console.error('[Hana] error:', e.message);
  }
  console.log(`[Hana] final events=${events.length}`);
  return events;
}

/** 메리츠증권: Puppeteer (JS 동적 렌더링)
 *  Python 검증: a[href="#none"] > dl > dd, 이벤트 기간 : YYYY.MM.DD ~ YYYY.MM.DD
 *  URL: https://home.imeritz.com/mobile/content/support/event_list.html
 */
async function scrapeMeritz() {
  const BASE = 'https://home.imeritz.com';
  const EVENT_URL = `${BASE}/mobile/content/support/event_list.html`;
  const PERIOD_RE = /이벤트\s*기간\s*:\s*(\d{4}\.\d{2}\.\d{2})\s*~\s*(\d{4}\.\d{2}\.\d{2})/;
  const today = new Date();
  const events = [];

  try {
    const puppeteerExtra = require('puppeteer-extra');
    const StealthPlugin = require('puppeteer-extra-plugin-stealth');
    const chromium = require('@sparticuz/chromium');
    puppeteerExtra.use(StealthPlugin());

    const browser = await puppeteerExtra.launch({
      args: chromium.args,
      defaultViewport: { width: 390, height: 844 },
      executablePath: await chromium.executablePath(),
      headless: true,
    });

    try {
      const page = await browser.newPage();
      await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      await page.goto(EVENT_URL, { waitUntil: 'networkidle2', timeout: 30000 });
      await new Promise(r => setTimeout(r, 6000));

      const html = await page.content();
      const $ = cheerio.load(html);

      $('a[href="#none"]').each((i, el) => {
        const dd = $(el).find('dd').first();
        if (!dd.length) return;

        const fullText = dd.text().replace(/\s+/g, ' ').trim();
        const periodMatch = fullText.match(PERIOD_RE);
        if (!periodMatch) return;

        const startDate = parseDate(periodMatch[1]);
        const endDate = parseDate(periodMatch[2]);

        // 진행중 필터
        if (endDate && endDate < today) return;
        if (startDate && startDate > today) return;

        const strong = dd.find('strong').first();
        let title = strong.text().trim();
        if (!title) {
          const beforePeriod = fullText.split('이벤트 기간')[0].trim();
          title = beforePeriod.split('\n')[0].trim().slice(0, 60);
        }
        if (!title) return;

        const dt = $(el).find('dt').first();
        const img = dt.find('img').first();
        let imageUrl = img.attr('src') || null;
        if (imageUrl && !imageUrl.startsWith('http')) imageUrl = BASE + imageUrl;

        events.push({
          id: `meritz_${i}`,
          title,
          description: title,
          brokerage: 'BrokerageType.meritz',
          category: guessCategory(title),
          startDate: startDate ? Timestamp.fromDate(startDate) : Timestamp.now(),
          endDate: endDate ? Timestamp.fromDate(endDate) : null,
          eventUrl: EVENT_URL,
          imageUrl,
          benefits: [],
          createdAt: Timestamp.now(),
        });
      });

      await page.close();
    } finally {
      await browser.close();
    }
  } catch (e) {
    console.error('[Meritz] error:', e.message);
  }
  console.log(`[Meritz] final events=${events.length}`);
  return events;
}

/** 키움증권: Puppeteer + Stealth (EverSafe 봇 감지 + iframe 구조)
 *  Python 검증: Selenium으로 iframe 내부 li[evnt_cd] 파싱
 *  evnt_cd 속성으로 이벤트 ID, img alt로 제목, span#evtPeriod로 날짜
 */
async function scrapeKiwoom() {
  const BASE = 'https://www.kiwoom.com';
  const EVENT_URL = `${BASE}/h/customer/event/VIngEventView`;
  const events = [];

  function getEventDetailUrl(evntCd, silgb) {
    if (silgb) {
      const compMap = {
        GF: '/h/mock/realcompetition/VRealCompetitionGFMView',
        DF: '/h/mock/realcompetition/VRealCompetitionDFMView',
        EF: '/h/mock/realcompetition/VRealCompetitionEFMView',
        GS: '/h/mock/realcompetition/VRealCompetitionGSMView',
        UC: '/h/mock/ordinary/VMockConTotalCHOMEView',
      };
      return BASE + (compMap[silgb] || `/h/mock/realcompetition/VRealCompetition${silgb}MView`);
    }
    if (evntCd.startsWith('I')) return `${BASE}/e/inv/event/${evntCd}Main`;
    if (evntCd.startsWith('EC')) {
      const num = parseInt(evntCd.slice(2, 8)) || 999999;
      return num <= 220001
        ? `${BASE}/wm/evt/evtMain${evntCd}View`
        : `${BASE}/e/wm/event/evtUser${evntCd}View`;
    }
    return `${BASE}/e/home/event/VEvent${evntCd}View`;
  }

  try {
    // 지연 로딩: 모듈 초기화 타임아웃 방지
    const puppeteerExtra = require('puppeteer-extra');
    const StealthPlugin = require('puppeteer-extra-plugin-stealth');
    const chromium = require('@sparticuz/chromium');
    puppeteerExtra.use(StealthPlugin());

    const browser = await puppeteerExtra.launch({
      args: chromium.args,
      defaultViewport: { width: 1280, height: 800 },
      executablePath: await chromium.executablePath(),
      headless: true,
    });

    try {
      const page = await browser.newPage();
      await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36');
      await page.setExtraHTTPHeaders({ 'Accept-Language': 'ko-KR,ko;q=0.9' });

      await page.goto(EVENT_URL, { waitUntil: 'networkidle2', timeout: 30000 });
      await new Promise(r => setTimeout(r, 8000));

      // iframe src를 추출해서 직접 방문 (contentFrame() 크로스오리진 문제 우회)
      const iframeSrc = await page.$eval('iframe', el => el.src).catch(() => null);
      console.log(`[Kiwoom] iframeSrc=${iframeSrc}`);

      if (iframeSrc) {
        await page.goto(iframeSrc, { waitUntil: 'networkidle2', timeout: 20000 });
        await new Promise(r => setTimeout(r, 5000));
      }

      const html = await page.content();
      const $ = cheerio.load(html);

      // li[evnt_cd] 속성으로 이벤트 탐색
      $('li[evnt_cd]').each((i, el) => {
        const evntCd = $(el).attr('evnt_cd') || '';
        const silgb = $(el).attr('silgb') || '';
        if (!evntCd) return;

        const img = $(el).find('img').first();
        const title = (img.attr('alt') || '').trim() || $(el).find('p').first().text().trim();
        if (!title) return;

        const periodText = $(el).find('span#evtPeriod').text().trim();
        const dateMatch = periodText.match(/(\d{4}\.\d{2}\.\d{2})\s*~\s*(\d{4}\.\d{2}\.\d{2})/);

        let imageUrl = img.attr('src') || null;
        if (imageUrl && !imageUrl.startsWith('http')) imageUrl = BASE + imageUrl;

        events.push({
          id: `kiwoom_${evntCd}`,
          title,
          description: title,
          brokerage: 'BrokerageType.kiwoom',
          category: guessCategory(title),
          startDate: dateMatch ? Timestamp.fromDate(parseDate(dateMatch[1])) : Timestamp.now(),
          endDate: dateMatch && parseDate(dateMatch[2]) ? Timestamp.fromDate(parseDate(dateMatch[2])) : null,
          eventUrl: getEventDetailUrl(evntCd, silgb),
          imageUrl,
          benefits: [],
          createdAt: Timestamp.now(),
        });
      });

      await page.close();
    } finally {
      await browser.close();
    }
  } catch (e) {
    console.error('[Kiwoom] error:', e.message);
  }
  console.log(`[Kiwoom] final events=${events.length}`);
  return events;
}

/** 신한투자증권: 공개 API (bbs2.shinhansec.com)
 *  Python 검증: GET https://bbs2.shinhansec.com/bbs/list/giEvent.do
 *  params: curPage, startPage, searchText=7A==, searchType=VARIABLE_FIELD2
 *  pagination: pageInfo.pages[1] → 다음 페이지의 startId
 *  필드: f1=제목, f6=시작일, f7=종료일, f8=messageId, f9=직접URL, f10=썸네일, f12=설명, fn=id
 */
async function scrapeShinhan() {
  const API_URL = 'https://bbs2.shinhansec.com/bbs/list/giEvent.do';
  const DETAIL_BASE = 'https://www.shinhansec.com/siw/customer-center/event/giEvent1/view.do';
  const SHINHAN_HEADERS = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
    'Referer': 'https://www.shinhansec.com/siw/customer-center/event/giEvent1/view.do',
    'Origin': 'https://www.shinhansec.com',
    'Accept': 'application/json',
  };
  const events = [];
  let curPage = 1, startPage = 1, startId = '';

  while (true) {
    try {
      const params = new URLSearchParams({
        curPage: String(curPage),
        startPage: String(startPage),
        searchText: '7A==',
        searchType: 'VARIABLE_FIELD2',
      });
      if (startId) params.set('startId', startId);

      const res = await axios.get(`${API_URL}?${params}`, { headers: SHINHAN_HEADERS, timeout: 10000 });
      const items = res.data?.list || [];
      if (!items.length) break;

      items.forEach((item, i) => {
        const title = (item.f1 || '').trim();
        if (!title) return;

        const startDate = parseDate((item.f6 || '').replace(/\//g, ''));
        const endDate = parseDate((item.f7 || '').replace(/\//g, ''));
        const eventUrl = item.f9 || `${DETAIL_BASE}?boardName=giEvent&messageId=${item.f8 || ''}`;

        events.push({
          id: `shinhan_${item.fn || i}`,
          title,
          description: (item.f12 || title).trim(),
          brokerage: 'BrokerageType.shinhan',
          category: guessCategory(title),
          startDate: startDate ? Timestamp.fromDate(startDate) : Timestamp.now(),
          endDate: endDate ? Timestamp.fromDate(endDate) : null,
          eventUrl,
          imageUrl: item.f10 || null,
          benefits: [],
          createdAt: Timestamp.now(),
        });
      });

      // 다음 페이지: pageInfo.pages[1]이 다음 startId
      const pages = res.data?.pageInfo?.pages || [];
      if (pages.length > 1) {
        startId = pages[1];
        curPage++;
        startPage++;
      } else {
        break;
      }
    } catch (e) {
      console.error(`[Shinhan] page=${curPage} error:`, e.message);
      break;
    }
  }
  console.log(`[Shinhan] final events=${events.length}`);
  return events;
}


// ─────────────────────────────────────────────
// 전체 수집 오케스트레이션
// ─────────────────────────────────────────────

async function scrapeAll() {
  // HTTP 스크래퍼 8개 병렬 실행
  const httpResults = await Promise.allSettled([
    scrapeSamsung(),
    scrapeMiraeAsset(),
    scrapeDaeshin(),
    scrapeKb(),
    scrapeKoreaInvestment(),
    scrapeShinhan(),
    scrapeNh(),
    scrapeHana(),
  ]);
  const httpEvents = httpResults
    .filter(r => r.status === 'fulfilled')
    .flatMap(r => r.value);
  console.log(`[HTTP] total=${httpEvents.length}`);

  // Puppeteer 스크래퍼 2개 순차 실행 (브라우저 메모리 절약)
  const kiwoomEvents = await scrapeKiwoom();
  const meritzEvents = await scrapeMeritz();
  console.log(`[Puppeteer] kiwoom=${kiwoomEvents.length}, meritz=${meritzEvents.length}`);

  return [...httpEvents, ...kiwoomEvents, ...meritzEvents];
}

// ─────────────────────────────────────────────
// Firestore 저장
// ─────────────────────────────────────────────

async function saveToFirestore(events) {
  if (events.length === 0) return;

  // 배치 단위로 저장 (Firestore 배치 최대 500건)
  const BATCH_SIZE = 400;
  for (let i = 0; i < events.length; i += BATCH_SIZE) {
    const batch = db.batch();
    const chunk = events.slice(i, i + BATCH_SIZE);
    for (const event of chunk) {
      const ref = db.collection(COLLECTION).doc(event.id);
      batch.set(ref, event, { merge: true });
    }
    await batch.commit();
  }
  console.log(`✅ Saved ${events.length} events to Firestore`);
}

// ─────────────────────────────────────────────
// 종료된 이벤트 삭제
// ─────────────────────────────────────────────

async function deleteExpiredEvents() {
  // 오늘 자정(KST) 기준으로 endDate가 지난 이벤트 삭제
  const now = new Date();
  const kstNow = new Date(now.getTime() + 9 * 60 * 60 * 1000);
  const todayMidnightKST = new Date(Date.UTC(
    kstNow.getUTCFullYear(),
    kstNow.getUTCMonth(),
    kstNow.getUTCDate(),
  ) - 9 * 60 * 60 * 1000);

  const snapshot = await db.collection(COLLECTION)
    .where('endDate', '<', Timestamp.fromDate(todayMidnightKST))
    .get();

  if (snapshot.empty) {
    console.log('No expired events to delete');
    return 0;
  }

  const BATCH_SIZE = 400;
  const docs = snapshot.docs;
  for (let i = 0; i < docs.length; i += BATCH_SIZE) {
    const batch = db.batch();
    docs.slice(i, i + BATCH_SIZE).forEach(doc => batch.delete(doc.ref));
    await batch.commit();
  }
  console.log(`🗑️ Deleted ${docs.length} expired events`);
  return docs.length;
}

// ─────────────────────────────────────────────
// 스케줄 함수: 평일(월-금) 오전 6시 (KST = UTC+9)
// ─────────────────────────────────────────────

exports.scrapeEvents = onSchedule(
  { schedule: '0 21 * * 1-5', timeZone: 'UTC', region: 'asia-northeast3', memory: '1GiB', timeoutSeconds: 300 },
  async () => {
    console.log('🚀 Starting scheduled event scraping...');
    const allEvents = await scrapeAll();
    console.log(`📦 Total scraped: ${allEvents.length} events`);
    await saveToFirestore(allEvents);
    await deleteExpiredEvents();
  }
);

// ─────────────────────────────────────────────
// HTTP 트리거: 수동 실행용 (테스트 및 즉시 수집)
// ─────────────────────────────────────────────

exports.scrapeEventsManual = onRequest(
  { region: 'asia-northeast3', timeoutSeconds: 300, memory: '1GiB' },
  async (req, res) => {
    const key = req.query.key || req.headers['x-api-key'];
    if (key !== 'stockpicker-manual-trigger') {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    console.log('🔧 Manual scrape triggered');
    const allEvents = await scrapeAll();
    await saveToFirestore(allEvents);
    await deleteExpiredEvents();
    res.json({ success: true, count: allEvents.length });
  }
);
