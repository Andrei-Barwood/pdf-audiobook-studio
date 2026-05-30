import re
from typing import List, Dict, Any
from app.core.text_cleaner import TextCleaner
from app.utils.logger import logger

class TextChunker:
    """Splits PDF page texts into logical and safely-sized blocks for optimal TTS synthesis."""

    @staticmethod
    def chunk_pages(pages: List[Dict[str, Any]], max_chars: int = 2000) -> List[Dict[str, Any]]:
        """
        Processes pages and yields a list of chunk dictionaries.
        Each page in 'pages' should contain:
            {"page_num": int (0-indexed), "raw_text": str}
            
        Returns a list of dicts:
            {
                "chunk_index": int,
                "page_number": int (1-indexed),
                "original_text": str,
                "clean_text": str
            }
        """
        chunks: List[Dict[str, Any]] = []
        chunk_idx = 0
        
        current_chunk_text = ""
        current_chunk_raw = ""
        # Keep track of which pages contributed to this chunk
        chunk_pages: List[int] = []

        # Sentence end boundaries
        sentence_end = re.compile(r'(?<=[.!?])\s+')

        for page in pages:
            page_num_1indexed = page["page_num"] + 1
            raw_text = page["raw_text"]
            
            # Clean the page text
            cleaned_page = TextCleaner.clean(raw_text)
            
            # If the page is empty, log it and skip to avoid sending empty inputs to TTS
            if not cleaned_page:
                logger.debug(f"Skipping empty page {page_num_1indexed}")
                continue
            
            # Split page cleaned text into sentences to avoid breaking mid-sentence
            sentences = sentence_end.split(cleaned_page)
            
            for sentence in sentences:
                sentence = sentence.strip()
                if not sentence:
                    continue
                
                # If adding this sentence would overflow our chunk limit and we already have content
                if len(current_chunk_text) + len(sentence) > max_chars and current_chunk_text:
                    # Flush the current chunk
                    chunks.append({
                        "chunk_index": chunk_idx,
                        "page_number": min(chunk_pages) if chunk_pages else page_num_1indexed,
                        "original_text": current_chunk_raw.strip(),
                        "clean_text": current_chunk_text.strip()
                    })
                    chunk_idx += 1
                    
                    # Reset variables
                    current_chunk_text = sentence + " "
                    current_chunk_raw = sentence + " "
                    chunk_pages = [page_num_1indexed]
                else:
                    current_chunk_text += sentence + " "
                    # Reconstruct raw approximation
                    current_chunk_raw += sentence + " "
                    if page_num_1indexed not in chunk_pages:
                        chunk_pages.append(page_num_1indexed)

        # Flush the final chunk if not empty
        if current_chunk_text.strip():
            chunks.append({
                "chunk_index": chunk_idx,
                "page_number": min(chunk_pages) if chunk_pages else pages[-1]["page_num"] + 1,
                "original_text": current_chunk_raw.strip(),
                "clean_text": current_chunk_text.strip()
            })
            
        logger.info(f"Chunked {len(pages)} pages into {len(chunks)} audio blocks (Max length limit: {max_chars} chars).")
        return chunks
