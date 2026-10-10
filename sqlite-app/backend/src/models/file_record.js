import { toBool } from "./index.js";

/**
 * @typedef {Object} FileRecordRecord
 * @property {string} fileId
 * @property {string} cartonId
 * @property {string} fileRef
 * @property {string} documentType
 * @property {string|null} fileDescription
 * @property {number|null} documentYear
 * @property {boolean} containsPii
 */

export const FileRecord = {
  table: "file_record",

  /** @returns {FileRecordRecord|null} */
  fromRow(row) {
    if (!row) return null;
    return {
      fileId: row.file_id,
      cartonId: row.carton_id,
      fileRef: row.file_ref,
      documentType: row.document_type,
      fileDescription: row.file_description,
      documentYear: row.document_year,
      containsPii: toBool(row.contains_pii),
    };
  },

  toPublic(f) {
    return {
      file_id: f.fileId,
      file_ref: f.fileRef,
      document_type: f.documentType,
      file_description: f.fileDescription,
      document_year: f.documentYear,
    };
  },
};
