import md5 from  "md5";
import moment from "moment";
import uniqid from "uniqid";

exports.md5 = function (value) {
  return md5(value);
};

exports.uniqId = function () {
  return uniqid.time();
};

exports.addToDate = function (amount, unit) {
  return moment().add(amount, unit).toISOString();
};
