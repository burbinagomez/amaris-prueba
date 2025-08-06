import React, { useEffect, useState } from 'react';
import FondosSection from './components/FondosSection';
import TransactionsSection from './components/TransactionsSection';
import SubscribeModal from './components/SubscribeModal';
import TransactionModal from './components/TransactionModal';

const API_BASE_URL = 'https://on395jxt36.execute-api.us-east-2.amazonaws.com/dev';

function App() {
  const [loading, setLoading] = useState(false);
  const [errorMessage, setErrorMessage] = useState('');
  const [successMessage, setSuccessMessage] = useState('');
  const [fondos, setFondos] = useState([]);
  const [transactions, setTransactions] = useState([]);
  const [userFunds, setUserFunds] = useState({});
  const [currentUserCedula, setCurrentUserCedula] = useState(localStorage.getItem('userCedula'));
  const [showFondos, setShowFondos] = useState(!currentUserCedula);
  const [showTransactions, setShowTransactions] = useState(!!currentUserCedula);
  const [showSubscribeModal, setShowSubscribeModal] = useState(false);
  const [showTransactionModal, setShowTransactionModal] = useState(false);
  const [subscribeFund, setSubscribeFund] = useState({});
  const [transactionFund, setTransactionFund] = useState('');
  const [transactionType, setTransactionType] = useState('');

  // API call helper
  const apiCall = async (url, method = 'GET', data = null) => {
    setLoading(true);
    setErrorMessage('');
    setSuccessMessage('');
    const options = {
      method,
      headers: { 'Content-Type': 'application/json' },
    };
    if (data) options.body = JSON.stringify(data);
    try {
      const response = await fetch(url, options);
      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.error || `Error en la petición: ${response.status}`);
      }
      return await response.json();
    } catch (error) {
      setErrorMessage(error.message);
      throw error;
    } finally {
      setLoading(false);
    }
  };

  // Fetch fondos
  useEffect(() => {
    if (showFondos) {
      apiCall(`${API_BASE_URL}/fondos`)
        .then(setFondos)
        .catch(() => {});
    }
  }, [showFondos]);

  // Fetch transactions
  useEffect(() => {
    if (showTransactions && currentUserCedula) {
      apiCall(`${API_BASE_URL}/transactions?user=${currentUserCedula}`)
        .then(data => {
          setTransactions(data);
          // Calculate user funds summary
          const summary = {};
          data.forEach(tx => {
            if (!summary[tx.fondo]) summary[tx.fondo] = 0;
            if (tx.tipo_transaccion === 'deposito') summary[tx.fondo] += tx.monto;
            else if (tx.tipo_transaccion === 'cancelacion') summary[tx.fondo] -= tx.monto;
          });
          setUserFunds(summary);
        })
        .catch(() => {});
    }
  }, [showTransactions, currentUserCedula]);

  // Handlers
  const handleSubscribe = (fund) => {
    setSubscribeFund(fund);
    setShowSubscribeModal(true);
  };

  const handleSubscribeSubmit = async (formData) => {
    try {
      await apiCall(`${API_BASE_URL}/subscribe`, 'POST', formData);
      setSuccessMessage('Suscripción exitosa. Redireccionando a tus transacciones...');
      setCurrentUserCedula(formData.cedula);
      localStorage.setItem('userCedula', formData.cedula);
      setShowSubscribeModal(false);
      setShowFondos(false);
      setShowTransactions(true);
    } catch {}
  };

  const handleTransaction = (fund, type) => {
    setTransactionFund(fund);
    setTransactionType(type);
    setShowTransactionModal(true);
  };

  const handleTransactionSubmit = async (formData) => {
    try {
      await apiCall(`${API_BASE_URL}/transactions`, 'POST', formData);
      setSuccessMessage('Transacción realizada con éxito.');
      setShowTransactionModal(false);
      setShowTransactions(true);
    } catch {}
  };

  const handleLogout = () => {
    setCurrentUserCedula(null);
    localStorage.removeItem('userCedula');
    setShowFondos(true);
    setShowTransactions(false);
    setSuccessMessage('Has cerrado sesión correctamente.');
  };

  return (
    <div className="container mx-auto p-6 bg-white shadow-lg rounded-xl">
      <h1 className="text-4xl font-bold text-center text-indigo-600 mb-8">Plataforma de Fondos</h1>
      {loading && <div className="text-center my-4 text-indigo-500 font-semibold">Cargando...</div>}
      {errorMessage && <div className="text-center my-4 text-red-500 font-semibold">{errorMessage}</div>}
      {successMessage && <div className="text-center my-4 text-green-500 font-semibold">{successMessage}</div>}
      {showFondos && (
        <FondosSection fondos={fondos} onSubscribe={handleSubscribe} />
      )}
      {showTransactions && (
        <TransactionsSection
          transactions={transactions}
          userFunds={userFunds}
          onTransaction={handleTransaction}
          onLogout={handleLogout}
        />
      )}
      <SubscribeModal
        show={showSubscribeModal}
        fund={subscribeFund}
        onClose={() => setShowSubscribeModal(false)}
        onSubmit={handleSubscribeSubmit}
      />
      <TransactionModal
        show={showTransactionModal}
        fund={transactionFund}
        type={transactionType}
        cedula={currentUserCedula}
        onClose={() => setShowTransactionModal(false)}
        onSubmit={handleTransactionSubmit}
      />
    </div>
  );
}

export default App;
