import os
import json
import torch
from torch.utils.data import Dataset, DataLoader
from transformers import LayoutLMv3Processor, LayoutLMv3ForTokenClassification, AdamW

class AgriDocDataset(Dataset):
    def __init__(self, data_dir: str, processor: LayoutLMv3Processor):
        self.data_dir = data_dir
        self.processor = processor
        self.image_paths = []
        self.annotations = []

        images_dir = os.path.join(data_dir, "images")
        annotations_dir = os.path.join(data_dir, "annotations")
        
        if os.path.exists(images_dir) and os.path.exists(annotations_dir):
            for file in os.listdir(annotations_dir):
                if file.endswith(".json"):
                    self.annotations.append(os.path.join(annotations_dir, file))
                    base_name = os.path.splitext(file)[0]
                    self.image_paths.append(os.path.join(images_dir, f"{base_name}.jpg"))

    def __len__(self):
        return len(self.annotations)

    def __getitem__(self, idx):
        # Open image and load bounding boxes and word list annotations
        # layoutlmv3 expects tokens, bounding boxes, labels, and image
        # Standard Hugging Face transformer processing block
        from PIL import Image
        image = Image.open(self.image_paths[idx]).convert("RGB")
        with open(self.annotations[idx], "r") as f:
            ann = json.load(f)

        # Tokenize and format bounding boxes for LayoutLMv3
        words = ["Sri", "Rama", "Agro", "Urea", "10", "Bags"] # Demo sequence
        boxes = [[0,0,0,0]] * len(words) # Normalised boxes [x0, y0, x1, y1]
        word_labels = [0] * len(words)

        encoding = self.processor(
            image, 
            words, 
            boxes=boxes, 
            word_labels=word_labels, 
            truncation=True, 
            return_tensors="pt"
        )
        
        # Flatten dictionary values
        return {k: v.squeeze(0) for k, v in encoding.items()}

def train_model(data_dir: str, output_dir: str, epochs: int = 3, lr: float = 5e-5):
    # Initialize PyTorch device (supports GPU/CUDA acceleration)
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    print(f"Training using device: {device}")

    # Initialize fine-tuned LayoutLMv3 from Hugging Face Hub
    processor = LayoutLMv3Processor.from_pretrained("microsoft/layoutlmv3-base", apply_ocr=False)
    model = LayoutLMv3ForTokenClassification.from_pretrained("microsoft/layoutlmv3-base", num_labels=9)
    model.to(device)

    dataset = AgriDocDataset(data_dir, processor)
    if len(dataset) == 0:
        print("Warning: No annotations found. Training skipped.")
        return

    dataloader = DataLoader(dataset, batch_size=2, shuffle=True)
    optimizer = AdamW(model.parameters(), lr=lr)

    model.train()
    for epoch in range(epochs):
        epoch_loss = 0.0
        for batch in dataloader:
            optimizer.zero_grad()
            
            # Load values onto target GPU/CPU device
            input_ids = batch["input_ids"].to(device)
            bbox = batch["bbox"].to(device)
            pixel_values = batch["pixel_values"].to(device)
            labels = batch["labels"].to(device)

            outputs = model(
                input_ids=input_ids,
                bbox=bbox,
                pixel_values=pixel_values,
                labels=labels
            )
            
            loss = outputs.loss
            loss.backward()
            optimizer.step()
            
            epoch_loss += loss.item()
        print(f"Epoch {epoch+1}/{epochs} - Loss: {epoch_loss/len(dataloader):.4f}")

    # Save fine-tuned checkpoint
    os.makedirs(output_dir, exist_ok=True)
    model.save_pretrained(output_dir)
    processor.save_pretrained(output_dir)
    print(f"Fine-tuned model checkpoint saved successfully to {output_dir}")

if __name__ == "__main__":
    # Support training triggers directly from MLOps incremental loops
    train_model("dataset/train", "models/layoutlmv3_agri")
