/**
 * Import function triggers from their respective submodules:
 *
 * import {onCall} from "firebase-functions/v2/https";
 * import {onDocumentWritten} from "firebase-functions/v2/firestore";
 *
 * See a full list of supported triggers at https://firebase.google.com/docs/functions
 */

import * as functions from "firebase-functions";
// import {onRequest} from "firebase-functions/https";
// import * as logger from "firebase-functions/logger";

// Start writing functions
// https://firebase.google.com/docs/functions/typescript

// For cost control, you can set the maximum number of containers that can be
// running at the same time. This helps mitigate the impact of unexpected
// traffic spikes by instead downgrading performance. This limit is a
// per-function limit. You can override the limit for each function using the
// `maxInstances` option in the function's options, e.g.
// `onRequest({ maxInstances: 5 }, (req, res) => { ... })`.
// NOTE: setGlobalOptions does not apply to functions using the v1 API. V1
// functions should each use functions.runWith({ maxInstances: 10 }) instead.
// In the v1 API, each function can only serve one request per container, so
// this will be the maximum concurrent request count.
functions.setGlobalOptions({ maxInstances: 10 });

// export const helloWorld = onRequest((request, response) => {
//   logger.info("Hello logs!", {structuredData: true});
//   response.send("Hello from Firebase!");
// });

export const flightStatus = functions.https.onRequest(async (req, res) => {
	res.set("Access-Control-Allow-Origin", "*");
	res.set("Access-Control-Allow-Headers", "*");
	if (req.method === "OPTIONS") {
		res.status(204).send("");
		return;
	}

	const flight = (req.query["flight"] as string | undefined)?.toUpperCase();
	const date = req.query["date"] as string | undefined; // YYYY-MM-DD
	if (!flight || !date) {
		res.status(400).json({ error: "Missing flight or date" });
		return;
	}

	// Example with Aviationstack; requires API key
	const API_KEY = process.env.AVIATIONSTACK_KEY;
	if (!API_KEY) {
		// Return a no-op mock if not configured
		res.json({
			flight,
			date,
			status: "unconfigured",
			departIso: undefined,
			arriveIso: undefined,
		});
		return;
	}
	try {
		const url = new URL("http://api.aviationstack.com/v1/flights");
		url.searchParams.set("access_key", API_KEY);
		url.searchParams.set("flight_iata", flight);
		url.searchParams.set("flight_date", date);
		const r = await fetch(url.toString());
		if (!r.ok) throw new Error(`API ${r.status}`);
		const json = (await r.json()) as any;
		const d =
			Array.isArray(json?.data) && json.data.length > 0
				? json.data[0]
				: undefined;
		const dep = d?.departure?.estimated ?? d?.departure?.scheduled ?? null;
		const arr = d?.arrival?.estimated ?? d?.arrival?.scheduled ?? null;
		const status = (d?.flight_status as string | undefined) ?? undefined;
		res.json({
			flight,
			date,
			status,
			departIso: dep ?? undefined,
			arriveIso: arr ?? undefined,
		});
	} catch (e: any) {
		res.status(500).json({ error: e?.message ?? String(e) });
	}
});
