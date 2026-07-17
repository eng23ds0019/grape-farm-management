import firebase_admin
from firebase_admin import firestore

class FarmMemoryService:
    @staticmethod
    def retrieve_memory(uid: str):
        """
        Retrieves the farmer's complete profile, diaries, expenses, and plot data
        directly from Firestore.
        """
        if not firebase_admin._apps:
            return {"error": "Firebase Admin not initialized", "data": {}}
            
        db = firestore.client()
        
        try:
            # 1. Fetch Farmer Profile
            farmer_doc = db.collection('users').document(uid).get()
            farmer_data = farmer_doc.to_dict() if farmer_doc.exists else {}
            
            # 2. Fetch Plots
            plots_ref = db.collection('users').document(uid).collection('plots').stream()
            plots = [p.to_dict() for p in plots_ref]
            
            # 3. Fetch Diaries (last 30)
            diaries_ref = db.collection('users').document(uid).collection('diary')\
                            .order_by('date', direction=firestore.Query.DESCENDING).limit(30).stream()
            diaries = [d.to_dict() for d in diaries_ref]
            
            # 4. Fetch Expenses (last 30)
            expenses_ref = db.collection('users').document(uid).collection('expenses')\
                             .order_by('date', direction=firestore.Query.DESCENDING).limit(30).stream()
            expenses = [e.to_dict() for e in expenses_ref]
            
            # 5. Fetch Chat Memory (last 10 interactions)
            chats_ref = db.collection('users').document(uid).collection('chats')\
                          .order_by('timestamp', direction=firestore.Query.DESCENDING).limit(10).stream()
            chats = [c.to_dict() for c in chats_ref]
            chats.reverse() # Chronological order
            
            return {
                "farmer": farmer_data,
                "plots": plots,
                "diaries": diaries,
                "expenses": expenses,
                "chats": chats
            }
        except Exception as e:
            print(f"Error retrieving farm memory for {uid}: {e}")
            return {"error": str(e), "data": {}}
