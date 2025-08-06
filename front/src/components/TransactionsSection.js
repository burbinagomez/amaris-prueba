import React from 'react';

function TransactionsSection({ transactions, userFunds, onTransaction, onLogout }) {
  return (
    <div>
      <div className="flex justify-between items-center mb-6">
        <h2 className="text-2xl font-semibold text-gray-800">Mis Transacciones</h2>
        <button
          className="bg-red-500 text-white font-bold py-2 px-4 rounded-lg shadow hover:bg-red-600 transition-colors duration-200"
          onClick={onLogout}
        >
          Cerrar Sesión
        </button>
      </div>
      <h3 className="text-xl font-semibold mt-8 mb-4 text-gray-800">Resumen de Inversiones</h3>
      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">
        {Object.entries(userFunds).map(([fundName, balance]) => (
          <div key={fundName} className="bg-white p-6 rounded-xl shadow-md border border-gray-200">
            <h4 className="text-lg font-bold text-indigo-600 mb-2">{fundName}</h4>
            <p className="text-2xl font-bold text-gray-800">${balance.toFixed(2)}</p>
            <div className="flex gap-2 mt-4">
              <button
                className="bg-blue-500 text-white font-bold py-2 px-4 rounded-lg hover:bg-blue-600 transition-colors duration-200"
                onClick={() => onTransaction(fundName, 'deposito')}
              >
                Depositar
              </button>
              <button
                className="bg-red-500 text-white font-bold py-2 px-4 rounded-lg hover:bg-red-600 transition-colors duration-200"
                onClick={() => onTransaction(fundName, 'cancelacion')}
              >
                Retirar
              </button>
            </div>
          </div>
        ))}
      </div>
      <h3 className="text-xl font-semibold mb-4 text-gray-800">Historial de Transacciones</h3>
      <div className="overflow-x-auto rounded-lg shadow-md">
        <table className="min-w-full bg-white text-gray-700">
          <thead className="bg-indigo-600 text-white">
            <tr>
              <th className="py-3 px-6 text-left font-bold uppercase tracking-wider">ID Transacción</th>
              <th className="py-3 px-6 text-left font-bold uppercase tracking-wider">Fondo</th>
              <th className="py-3 px-6 text-left font-bold uppercase tracking-wider">Tipo</th>
              <th className="py-3 px-6 text-left font-bold uppercase tracking-wider">Monto</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {transactions.map(tx => (
              <tr key={tx.id} className="hover:bg-gray-50">
                <td className="py-4 px-6">{tx.id}</td>
                <td className="py-4 px-6">{tx.fondo}</td>
                <td className="py-4 px-6">{tx.tipo_transaccion}</td>
                <td className="py-4 px-6">${tx.monto}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default TransactionsSection;
