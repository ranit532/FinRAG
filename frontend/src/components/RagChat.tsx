import { useState } from 'react';
import axios from 'axios';

type ChatMessage = {
  role: 'user' | 'assistant';
  content: string;
};

const RagChat = () => {
  const [messages, setMessages] = useState<ChatMessage[]>([]);
  const [query, setQuery] = useState('');
  const [isLoading, setIsLoading] = useState(false);

  const handleSubmit = async (event: React.FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    if (!query.trim()) {
      return;
    }

    const newMessage: ChatMessage = { role: 'user', content: query };
    setMessages((prev) => [...prev, newMessage]);
    setIsLoading(true);

    try {
      const response = await axios.post(
        import.meta.env.VITE_API_BASE_URL ?? '/api/rag/query',
        { question: query }
      );
      const assistantMessage: ChatMessage = {
        role: 'assistant',
        content: response.data.answer ?? 'No answer returned.'
      };
      setMessages((prev) => [...prev, assistantMessage]);
    } catch (error) {
      setMessages((prev) => [
        ...prev,
        {
          role: 'assistant',
          content:
            'We could not reach the RAG backend. Please check configuration.'
        }
      ]);
      console.error(error);
    } finally {
      setIsLoading(false);
      setQuery('');
    }
  };

  return (
    <section className="chat-panel">
      <div className="messages" data-testid="messages">
        {messages.map((message, index) => (
          <article key={`${message.role}-${index}`} className={`message ${message.role}`}>
            <strong>{message.role === 'user' ? 'Broker' : 'Copilot'}</strong>
            <p>{message.content}</p>
          </article>
        ))}
        {isLoading && <p className="meta">Thinking...</p>}
      </div>
      <form onSubmit={handleSubmit} className="query-form">
        <input
          type="text"
          value={query}
          placeholder="Ask about loss ratios, premiums, or claim limits..."
          onChange={(event) => setQuery(event.target.value)}
          disabled={isLoading}
        />
        <button type="submit" disabled={isLoading}>
          Ask
        </button>
      </form>
      <p className="meta">
        Responses are grounded on simulated insurance policy packets synchronized
        via Pinecone and Azure OpenAI embeddings.
      </p>
    </section>
  );
};

export default RagChat;
