import RagChat from './components/RagChat';

const App = () => {
  return (
    <div className="app-shell">
      <header>
        <h1>Insurance RAG Copilot</h1>
        <p>Query transactional documents securely via Azure OpenAI</p>
      </header>
      <main>
        <RagChat />
      </main>
    </div>
  );
};

export default App;

