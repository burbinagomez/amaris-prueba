import React, { useState } from 'react';

function TransactionModal({ show, fund, type, cedula, onClose, onSubmit }) {
  const [monto, setMonto] = useState('');

  if (!show) return null;

  const handleSubmit = (e) => {
    e.preventDefault();
    onSubmit({
      cedula,
      fondo: fund,
      operacion: type,
      monto: parseFloat(monto)
    });
  };

  return (
    <div className="fixed inset-0 flex items-center justify-center z-50 modal-overlay">
      <div className="bg-white p-8 rounded-xl shadow-2xl w-full max-w-md mx-4">
        <div className="flex justify-between items-center mb-6">
          <h3 className="text-2xl font-bold text-indigo-600">{type === 'deposito' ? 'Realizar Depósito' : 'Realizar Retiro'} en {fund}</h3>
          <button onClick={onClose} className="text-gray-400 hover:text-gray-600 text-3xl font-bold">&times;</button>
        </div>
        <form onSubmit={handleSubmit} className="space-y-4">
          <div>
            <label className="block text-gray-700 font-semibold mb-1">Cédula</label>
            <input type="text" value={cedula} disabled className="w-full px-4 py-2 border border-gray-300 rounded-lg bg-gray-100 cursor-not-allowed" />
          </div>
          <div>
            <label className="block text-gray-700 font-semibold mb-1">Monto</label>
            <input type="number" value={monto} onChange={e => setMonto(e.target.value)} required className="w-full px-4 py-2 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-indigo-500" />
          </div>
          <button type="submit" className="w-full bg-indigo-600 text-white font-bold py-3 rounded-lg shadow-md hover:bg-indigo-700 transition-colors duration-200">
            Confirmar
          </button>
        </form>
      </div>
    </div>
  );
}

export default TransactionModal;
