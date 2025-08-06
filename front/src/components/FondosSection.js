import React from 'react';

function FondosSection({ fondos, onSubscribe }) {
  return (
    <div>
      <h2 className="text-2xl font-semibold mb-4 text-gray-800">Fondos Disponibles</h2>
      <div className="overflow-x-auto rounded-lg shadow-md">
        <table className="min-w-full bg-white text-gray-700">
          <thead className="bg-indigo-600 text-white">
            <tr>
              <th className="py-3 px-6 text-left font-bold uppercase tracking-wider">Nombre</th>
              <th className="py-3 px-6 text-left font-bold uppercase tracking-wider">Categoría</th>
              <th className="py-3 px-6 text-left font-bold uppercase tracking-wider">Monto Mínimo</th>
              <th className="py-3 px-6 text-left font-bold uppercase tracking-wider">Acción</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {fondos.map((fondo, idx) => (
              <tr key={idx} className="hover:bg-gray-50">
                <td className="py-4 px-6">{fondo.nombre}</td>
                <td className="py-4 px-6">{fondo.categoria}</td>
                <td className="py-4 px-6">${fondo.monto_minimo}</td>
                <td className="py-4 px-6">
                  <button
                    className="bg-green-500 text-white font-bold py-2 px-4 rounded-lg shadow hover:bg-green-600 transition-colors duration-200"
                    onClick={() => onSubscribe(fondo)}
                  >
                    Suscribir
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export default FondosSection;
