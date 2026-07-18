"""
Farm Memory Service — Retrieves farmer's complete data from Firestore.
Uses Firebase Admin SDK. Caches for 5 minutes to minimize reads.
"""
import time
from typing import Dict, Any

_cache: Dict[str, Any] = {}
_cache_ttl = 300  # 5 minutes


def retrieve_farm_memory(uid: str) -> dict:
    """Pull farmer profile, plots, diaries, expenses, sprays from Firestore."""
    if not uid:
        return _empty_memory()

    # Cache check
    cache_key = f"memory_{uid}"
    cached = _cache.get(cache_key)
    if cached and (time.time() - cached["_ts"]) < _cache_ttl:
        return cached["data"]

    try:
        import firebase_admin
        from firebase_admin import firestore as fs

        if not firebase_admin._apps:
            print("⚠️  Firebase Admin not initialized")
            return _empty_memory()

        db = fs.client()

        # Farmer profile
        farmer_doc = db.collection("users").document(uid).get()
        farmer = farmer_doc.to_dict() if farmer_doc.exists else {}

        # Plots (Try cropRecords first, fallback to plots)
        plots = []
        try:
            plots = [p.to_dict() for p in db.collection("users").document(uid).collection("cropRecords").stream()]
        except Exception:
            pass
        if not plots:
            try:
                plots = [p.to_dict() for p in db.collection("users").document(uid).collection("plots").stream()]
            except Exception:
                pass

        # Diary (Try diaryEntries first, fallback to diary)
        diaries = []
        try:
            diaries = [
                d.to_dict()
                for d in db.collection("users").document(uid).collection("diaryEntries")
                .order_by("date", direction=fs.Query.DESCENDING).limit(20).stream()
            ]
        except Exception:
            try:
                diaries = [
                    d.to_dict()
                    for d in db.collection("users").document(uid).collection("diary")
                    .order_by("date", direction=fs.Query.DESCENDING).limit(20).stream()
                ]
            except Exception:
                pass

        # Expenses (last 15)
        expenses = []
        try:
            expenses = [
                e.to_dict()
                for e in db.collection("users").document(uid).collection("expenses")
                .order_by("date", direction=fs.Query.DESCENDING).limit(15).stream()
            ]
        except Exception:
            pass

        # Conversation history (last 6 messages for context)
        chats = []
        try:
            raw = [
                c.to_dict()
                for c in db.collection("users").document(uid).collection("chats")
                .order_by("timestamp", direction=fs.Query.DESCENDING).limit(6).stream()
            ]
            chats = list(reversed(raw))
        except Exception:
            pass

        result = {
            "farmer": farmer,
            "plots": plots,
            "diaries": diaries,
            "expenses": expenses,
            "chats": chats,
        }

        # Save to cache
        _cache[cache_key] = {"data": result, "_ts": time.time()}
        return result

    except Exception as e:
        print(f"❌ FarmMemory error for {uid}: {e}")
        return _empty_memory()


def invalidate_cache(uid: str):
    """Call this after new diary/expense is saved."""
    _cache.pop(f"memory_{uid}", None)


def _empty_memory() -> dict:
    return {"farmer": {}, "plots": [], "diaries": [], "expenses": [], "chats": []}
