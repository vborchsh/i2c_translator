# i2c_translator
I2C interface FPGA implementation translator

Модуль-транслятор для интерфейса I2C.
Работает "на проход" по схеме MASTER <-> FPGA <-> SLAVE's.

Поддерживается запись/чтение произвольного количества байт.
Проверена работа в связке с i2cget/set for Linux.
