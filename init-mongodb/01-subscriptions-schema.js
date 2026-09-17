// Esquema inklusport_subscriptions (RF54-RF68) en MongoDB.
// Equivalente al antiguo init-mysql/10-subscriptions-schema.sql: crea las colecciones,
// los validadores de campos obligatorios y los índices que antes eran UNIQUE KEY / INDEX.
//
// IDs de organizador/usuario/evento alineados con user_ms y sports_events_ms (UUID en
// texto). No hay integridad referencial entre microservicios: esos campos son referencias
// lógicas. Los identificadores propios (plan, suscripcion, pago, ...) son enteros que
// asigna la aplicación con la colección `contador_secuencia`, porque la API y los otros
// micros ya referencian planes y pagos por número.
//
// OJO: docker-entrypoint-initdb.d solo se ejecuta cuando el volumen de datos está vacío.
// Sobre un volumen ya creado hay que lanzarlo a mano:
//   docker exec -i inklusport-mongodb mongosh -u admin -p admin123 \
//     --authenticationDatabase admin < init-mongodb/01-subscriptions-schema.js
// El catálogo de planes lo siembra la aplicación (PlanSeeder), no este script.

const db = db.getSiblingDB('inklusport_subscriptions');

function coleccion(nombre, requeridos) {
  if (!db.getCollectionNames().includes(nombre)) {
    db.createCollection(nombre, {
      validator: { $jsonSchema: { bsonType: 'object', required: requeridos } },
      validationLevel: 'moderate'
    });
  }
}

// --- Contador que sustituye al AUTO_INCREMENT de MySQL -----------------------
coleccion('contador_secuencia', ['valor']);

// --- RF54 / RF64 / RF65: catalogo de planes ---------------------------------
coleccion('plan', ['nombre', 'precio', 'duracion_dias', 'activo']);
db.plan.createIndex({ nombre: 1 }, { name: 'uk_plan_nombre', unique: true });
db.plan.createIndex({ activo: 1 }, { name: 'idx_plan_activo' });
// RF64: como maximo un plan inicial activo a la vez.
db.plan.createIndex(
  { es_plan_inicial: 1 },
  { name: 'uk_plan_inicial', unique: true, partialFilterExpression: { es_plan_inicial: true } }
);

coleccion('beneficio_plan', ['plan_id', 'beneficio']);
db.beneficio_plan.createIndex({ plan_id: 1, orden: 1 }, { name: 'idx_beneficio_plan' });

coleccion('funcionalidad_plan', ['plan_id', 'codigo', 'nombre']);
db.funcionalidad_plan.createIndex(
  { plan_id: 1, codigo: 1 },
  { name: 'uk_funcionalidad_plan', unique: true }
);

coleccion('historial_plan', ['plan_id', 'campo_modificado']);
db.historial_plan.createIndex({ plan_id: 1, fecha_modificacion: -1 }, { name: 'idx_historial_plan' });

// --- RF56 / RF57 / RF58 / RF59 / RF64: suscripcion del organizador ----------
coleccion('suscripcion', ['organizador_id', 'plan_id', 'fecha_inicio', 'fecha_fin', 'estado']);
db.suscripcion.createIndex({ organizador_id: 1 }, { name: 'idx_suscripcion_organizador' });
db.suscripcion.createIndex({ estado: 1, fecha_fin: 1 }, { name: 'idx_suscripcion_estado_fin' });

// RF61: historial de altas, renovaciones, cambios de plan y estados.
coleccion('historial_suscripcion', ['suscripcion_id', 'tipo_movimiento']);
db.historial_suscripcion.createIndex(
  { suscripcion_id: 1, fecha_movimiento: -1 },
  { name: 'idx_historial_suscripcion' }
);
// En Mongo no hay JOIN: el panel de admin filtra el historial por organizador.
db.historial_suscripcion.createIndex({ organizador_id: 1 }, { name: 'idx_historial_organizador' });

// --- RF68: transacciones y webhooks de la pasarela --------------------------
coleccion('transaccion_pasarela', ['pasarela', 'tipo', 'monto']);
// No usar sparse: Mongo indexa preferencia_id:null y el 2.º cobro con tarjeta (RF70,
// sin Checkout Pro) falla con E11000. Solo unicidad si hay preference id real.
db.transaccion_pasarela.createIndex(
  { pasarela: 1, preferencia_id: 1 },
  {
    name: 'uk_preferencia',
    unique: true,
    partialFilterExpression: { preferencia_id: { $type: 'string' } }
  }
);
db.transaccion_pasarela.createIndex(
  { pasarela: 1, pago_externo_id: 1 },
  {
    name: 'uk_pago_externo',
    unique: true,
    partialFilterExpression: { pago_externo_id: { $type: 'string' } }
  }
);
db.transaccion_pasarela.createIndex({ referencia_externa: 1 }, { name: 'idx_referencia_externa' });
db.transaccion_pasarela.createIndex({ estado_pasarela: 1 }, { name: 'idx_estado_pasarela' });

coleccion('webhook_pasarela', ['pasarela', 'tipo_notificacion', 'payload']);
db.webhook_pasarela.createIndex({ pasarela: 1, id_externo: 1 }, { name: 'idx_webhook_externo' });
db.webhook_pasarela.createIndex({ procesado: 1, fecha_recepcion: 1 }, { name: 'idx_webhook_pendiente' });

// --- RF56 / RF59: pagos de planes de organizador ----------------------------
coleccion('pago_suscripcion', ['suscripcion_id', 'monto', 'estado']);
db.pago_suscripcion.createIndex({ suscripcion_id: 1, estado: 1 }, { name: 'idx_pago_suscripcion' });
db.pago_suscripcion.createIndex({ referencia_transaccion: 1 }, { name: 'idx_pago_suscripcion_referencia' });
db.pago_suscripcion.createIndex({ organizador_id: 1, fecha_pago: -1 }, { name: 'idx_pago_suscripcion_organizador' });

// --- RF63: evento gratuito o de pago ---------------------------------------
coleccion('configuracion_evento_pago', ['evento_id', 'organizador_id', 'es_pago']);
db.configuracion_evento_pago.createIndex({ evento_id: 1 }, { name: 'uk_config_evento', unique: true });
db.configuracion_evento_pago.createIndex({ organizador_id: 1 }, { name: 'idx_config_organizador' });

// --- RF55 / RF66: inscripcion pagada a un evento ---------------------------
coleccion('pago_evento', ['usuario_id', 'evento_id', 'organizador_id', 'monto', 'estado']);
db.pago_evento.createIndex({ usuario_id: 1, fecha_pago: -1 }, { name: 'idx_pago_evento_usuario' });
db.pago_evento.createIndex({ evento_id: 1, estado: 1 }, { name: 'idx_pago_evento_evento' });
db.pago_evento.createIndex({ organizador_id: 1 }, { name: 'idx_pago_evento_organizador' });
db.pago_evento.createIndex({ referencia_transaccion: 1 }, { name: 'idx_pago_evento_referencia' });

// --- RF67: comprobante de pago e inscripcion -------------------------------
coleccion('comprobante_pago', ['numero_comprobante', 'tipo', 'monto']);
db.comprobante_pago.createIndex(
  { numero_comprobante: 1 },
  { name: 'uk_numero_comprobante', unique: true }
);
db.comprobante_pago.createIndex({ pago_evento_id: 1 }, { name: 'idx_comprobante_evento', sparse: true });
db.comprobante_pago.createIndex(
  { pago_suscripcion_id: 1 },
  { name: 'idx_comprobante_suscripcion', sparse: true }
);

// --- RF60: avisos de vencimiento -------------------------------------------
coleccion('notificacion_vencimiento', ['suscripcion_id', 'dias_antes', 'fecha_programada']);
db.notificacion_vencimiento.createIndex(
  { suscripcion_id: 1, dias_antes: 1, fecha_programada: 1 },
  { name: 'uk_notif_ciclo', unique: true }
);
db.notificacion_vencimiento.createIndex(
  { estado: 1, fecha_programada: 1 },
  { name: 'idx_notif_pendiente' }
);

// --- Parametros del dominio ------------------------------------------------
coleccion('parametro_suscripciones', ['valor']);
[
  { _id: 'dias_aviso_vencimiento', valor: '7,3,1', descripcion: 'Días antes del vencimiento para notificar (RF60)' },
  { _id: 'pasarela_activa', valor: 'MERCADOPAGO', descripcion: 'Pasarela de cobro (RF68). MOCK en desarrollo.' },
  { _id: 'moneda_default', valor: 'COP', descripcion: 'Moneda de cobro (Mercado Pago Colombia)' },
  { _id: 'renovacion_automatica_default', valor: 'false', descripcion: 'Valor inicial de renovación automática' }
].forEach((parametro) => {
  db.parametro_suscripciones.updateOne(
    { _id: parametro._id },
    { $setOnInsert: { valor: parametro.valor, descripcion: parametro.descripcion, actualizado_en: new Date() } },
    { upsert: true }
  );
});

print('inklusport_subscriptions: colecciones e indices listos');
