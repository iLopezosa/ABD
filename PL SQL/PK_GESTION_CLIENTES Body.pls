create or replace PACKAGE BODY PK_GESTION_CLIENTES AS

  PROCEDURE ALTA_CLIENTE(P_ID_CLIENTE IN CLIENTE.ID%TYPE,
P_IDENTIFICACION IN CLIENTE.IDENTIFICACION%TYPE,
P_TIPO_CLIENTE   IN CLIENTE.TIPO_CLIENTE%TYPE,
P_ESTADO         IN CLIENTE.ESTADO%TYPE,
P_FECHA_ALTA     IN CLIENTE.FECHA_ALTA%TYPE,
P_FECHA_BAJA              IN CLIENTE.FECHA_BAJA%TYPE,     
P_DIRECCION      IN CLIENTE.DIRECCION%TYPE,
P_CIUDAD         IN CLIENTE.CIUDAD%TYPE,
P_CODIGO_POSTAL  IN CLIENTE.CODIGO_POSTAL%TYPE,
P_PAIS           IN CLIENTE.PAIS%TYPE,
P_RAZON_SOCIAL IN EMPRESA.RAZON_SOCIAL%TYPE,
P_NOMBRE           IN INDIVIDUAL.NOMBRE%TYPE, 
P_APELLIDO         IN INDIVIDUAL.APELLIDO%TYPE,
P_FECHA_NACIMIENTO          IN INDIVIDUAL.FECHA_NACIMIENTO%TYPE) IS
ESTADO_CLIENTE       CLIENTE.ESTADO%TYPE;
CLIENTE_ID           CLIENTE.ID%TYPE;
  BEGIN
    -- AL USAR SEQUENCE YA NO ES NECESARIO COMPROBAR ID 
    SELECT ID INTO CLIENTE_ID FROM CLIENTE WHERE ID LIKE P_ID_CLIENTE;
    -- CHECK DE EXISTENCIA DE CLIENTE (HABIA UN ERROR)
    IF CLIENTE_ID IS NOT NULL THEN 
        RAISE CLIENTE_EXISTENTE_EXCEPTION;
    END IF;

    --Insertamos el cliente
        INSERT INTO CLIENTE (
            id,
            identificacion,
            tipo_cliente,
            estado,
            fecha_alta,
            fecha_baja,
            direccion,
            ciudad,
            codigo_postal,
            pais
        ) VALUES (
            SQ_CLIENTE.NEXTVAL;
            P_IDENTIFICACION,
            P_TIPO_CLIENTE,
            P_ESTADO,
            P_FECHA_ALTA,
            P_FECHA_BAJA,     
            P_DIRECCION,
            P_CIUDAD,
            P_CODIGO_POSTAL,
            P_PAIS
        );
    
    IF P_TIPO_CLIENTE = 'EMPRESA' THEN 
        --Insertar empresa
        INSERT INTO EMPRESA (
            cliente_id,
            razon_social
        ) VALUES (
            SQ_CLIENTE.CURRVAL,
            P_RAZON_SOCIAL
        );
    ELSIF P_TIPO_CLIENTE = 'INDIVIDUAL' THEN
        --Insertar individual
            INSERT INTO individual (
            cliente_id,
            nombre,
            apellido,
            fecha_nacimiento
        ) VALUES (
            SQ_CLIENTE.CURRVAL,
            P_NOMBRE,
            P_APELLIDO,
            P_FECHA_NACIMIENTO
        );
    ELSE
        RAISE CLIENTE_NO_VALIDO_EXCEPTION;
    END IF;    
  END ALTA_CLIENTE;

  PROCEDURE MOD_CLIENTE(P_ID_CLIENTE IN CLIENTE.ID%TYPE, 
P_IDENTIFICACION IN CLIENTE.IDENTIFICACION%TYPE,
P_TIPO_CLIENTE   IN CLIENTE.TIPO_CLIENTE%TYPE,
P_ESTADO         IN CLIENTE.ESTADO%TYPE,
P_FECHA_ALTA     IN CLIENTE.FECHA_ALTA%TYPE,
P_FECHA_BAJA              IN CLIENTE.FECHA_BAJA%TYPE,     
P_DIRECCION      IN CLIENTE.DIRECCION%TYPE,
P_CIUDAD         IN CLIENTE.CIUDAD%TYPE,
P_CODIGO_POSTAL  IN CLIENTE.CODIGO_POSTAL%TYPE,
P_PAIS           IN CLIENTE.PAIS%TYPE,
P_RAZON_SOCIAL IN EMPRESA.RAZON_SOCIAL%TYPE,
P_NOMBRE            IN INDIVIDUAL.NOMBRE%TYPE, 
P_APELLIDOS         IN INDIVIDUAL.APELLIDO%TYPE,
P_FECHA_NACIMIENTO        IN INDIVIDUAL.FECHA_NACIMIENTO%TYPE) IS
CLIENTE_AUX         CLIENTE.ID%TYPE;
IDENTIFICACION_AUX  CLIENTE.IDENTIFICACION%TYPE;
AUX                 INTEGER;
  BEGIN
	SELECT ID INTO CLIENTE_AUX FROM CLIENTE WHERE ID LIKE P_ID_CLIENTE;
    IF CLIENTE_AUX IS NULL THEN
		RAISE CLIENTE_NO_EXISTENTE_EXCEPTION;
	ELSE
		-- La identificación solo se actualiza si no existe en la base de datos
        -- En caso de que la identificación no se haya cambiado se mantendrá la misma y no se actualizará
        -- En caso de que se quiera cambiar la identificación por una que ya tiene otro cliente se lanzará un ERROR
        -- En caso de que la identificación se quiera cambiar por una que no tenga ningún cliente se actualizará el valor en la tabla
        SELECT COUNT(CLIENTE.IDENTIFICACION) INTO AUX FROM CLIENTE WHERE IDENTIFICACION LIKE P_IDENTIFICACION;
        SELECT IDENTIFICACION INTO IDENTIFICACION_AUX FROM CLIENTE WHERE ID LIKE P_ID_CLIENTE;
		IF AUX == 0 THEN
			UPDATE CLIENTE
       		SET
       			IDENTIFICACION = P_IDENTIFICACION
        	WHERE
    			ID = P_ID_CLIENTE;
        ELSIF IDENTIFICACION_AUX <> P_IDENTIFICACION
            RAISE DATOS_INCORRECTOS_EXCEPTION;
		END IF;
        UPDATE CLIENTE
            SET
        		TIPO_CLIENTE = P_TIPO_CLIENTE
                ESTADO = P_ESTADO
                FECHA_ALTA = P_FECHA_ALTA
                FECHA_BAJA = P_FECHA_BAJA
                DIRECCION = P_DIRECCION
                CIUDAD = P_CIUDAD
                CODIGO_POSTAL = P_CODIGO_POSTAL
                PAIS = P_PAIS
        	WHERE
        		ID = P_ID_CLIENTE;

        -- Se comprueba si es empresa o individual
		IF P_RAZON_SOCIAL IS NOT NULL THEN
			UPDATE EMPRESA
        		SET
            			RAZON_SOCIAL = P_RAZON_SOCIAL
        		WHERE
            			CLIENTE_ID = P_ID_CLIENTE;
		ELSE
			UPDATE INDIVIDUAL
        		SET
            			NOMBRE = P_NOMBRE
                        APELLIDO = P_APELLIDOS
                        FECHA_NACIMIENTO = P_FECHA_NACIMIENTO
        		WHERE
            			CLIENTE_ID = P_ID_CLIENTE;
		END IF;
	END IF;
    EXCEPTION
    WHEN DATOS_INCORRECTOS_EXCEPTION then
    DBMS_OUTPUT.PUT_LINE('Identificacion existente en otro cliente, debe ser única')
  END MOD_CLIENTE;

PROCEDURE BAJA_CLIENTE(
P_IDENTIFICACION    IN CLIENTE.IDENTIFICACION%TYPE)
IS
ESTADO_CLIENTE      CLIENTE.ESTADO%TYPE;
CLIENTE_ID          CLIENTE.ID%TYPE;
CONT                INTEGER;
BEGIN
    SELECT ESTADO, ID INTO ESTADO_CLIENTE, CLIENTE_ID FROM CLIENTE WHERE IDENTIFICACION LIKE P_IDENTIFICACION;
    -- CHECK DE EXISTENCIA DE CLIENTE (HABIA UN ERROR)
    IF CLIENTE_ID IS NULL THEN 
        RAISE CLIENTE_NO_EXISTENTE_EXCEPTION;
    END IF;

    -- check de numero de cuentas, si tiene alguna cuenta fintech que haga referencia al cliente, saltara excepcion
    SELECT COUNT(CLIENTE_ID) INTO CONT FROM CUENTA_FINTECH WHERE CLIENTE_ID LIKE CLIENTE_ID;
    IF CONT > 0 THEN
        RAISE CUENTAS_ACTIVAS_EXCEPTION;
    END IF;

    -- check de estado del cliente, si esta ya inactivo saltara una excepcion, en otro caso se setea su estado a inactivo y la fecha de baja se actualiza
    IF ESTADO_CLIENTE NOT LIKE 'ACTIV[OAE]' THEN
        RAISE ESTADO_INACTIVO_EXCEPTION;
    ELSE
        UPDATE CLIENTE
        SET
            ESTADO = 'INACTIVO',
            FECHA_BAJA = SYSDATE
        WHERE
            IDENTIFICACION = P_IDENTIFICACION;
    END IF;
END BAJA_CLIENTE;

  PROCEDURE BAJA_CLIENTE(P_ID_CLIENTE IN CLIENTE.ID%TYPE) AS
  BEGIN
    -- TAREA: Se necesita implantación para PROCEDURE PK_GESTION_CLIENTES.BAJA_CLIENTE
    NULL;
  END BAJA_CLIENTE;

  PROCEDURE ALTA_AUTORIZADO(P_ID_AUTORIZADO              IN PERSONA_AUTORIZADA.ID%TYPE,
P_IDENTIFICACION   IN PERSONA_AUTORIZADA.IDENTIFICACION%TYPE,
P_NOMBRE           IN PERSONA_AUTORIZADA.NOMBRE%TYPE,
P_APELLIDOS        IN PERSONA_AUTORIZADA.APELLIDOS%TYPE, 
P_DIRECCION        IN PERSONA_AUTORIZADA.DIRECCION%TYPE,
P_FECHA_NACIMIENTO          IN PERSONA_AUTORIZADA.FECHA_NACIMIENTO%TYPE,
P_FECHA_INICIO              IN PERSONA_AUTORIZADA.FECHA_INICIO%TYPE,
P_ESTADO                    IN PERSONA_AUTORIZADA.ESTADO%TYPE,
P_FECHA_FIN                 IN PERSONA_AUTORIZADA.FECHA_FIN%TYPE,
P_TIPO   IN AUTORIZACION.TIPO%TYPE,
P_ID_EMPRESA IN AUTORIZACION.EMPRESA_ID%TYPE) 
 IS
 ID_AUX              PERSONA_AUTORIZADA.ID%TYPE;
  BEGIN
	SELECT ID INTO ID_AUX FROM PERSONA_AUTORIZADA WHERE ID LIKE P_ID_AUTORIZADO;
 	IF ID_AUX IS NULL THEN
 		INSERT INTO PERSONA_AUTORIZADA (
 			ID,
 			IDENTIFICACION,
 			NOMBRE,
 			APELLIDOS,
 			DIRECCION,
 			FECHA_NACIMIENTO,
 			FECHA_INICIO,
 			ESTADO,
 			FECHA_FIN
 		) VALUES (
 			SQ_PERSONA.NEXTVAL,
 			P_IDENTIFICACION,
 			P_NOMBRE,
 			P_APELLIDOS,
 			P_DIRECCION,
 			P_FECHA_NACIMIENTO,
 			P_FECHA_INICIO,
 			P_ESTADO,
 			P_FECHA_FIN
 		);
 	END IF;
	IF P_TIPO <> 'CONSULTA' AND P_TIPO <> 'OPERACI[ÓO]N' THEN
		RAISE DATOS_INCORRECTOS_EXCEPTION;
	ELSE
 		INSERT INTO AUTORIZACION (TIPO, PERSONA_AUTORIZADA_ID, EMPRESA_ID)
 			VALUES (P_TIPO, SQ_PERSONA.CURRVAL, P_ID_EMPRESA);
	END IF;
    EXCEPTION
    WHEN RAISE_DATOS_INCORRECTOS_EXCEPTION THEN
    DBMS_OUTPUT.PUT_LINE('Tipo de relación empresa-autorizado incorrecta, debe ser CONSULTA u OPERACION')
  END ALTA_AUTORIZADO;

  PROCEDURE BAJA_AUTORIZADO(ID               IN PERSONA_AUTORIZADA.ID%TYPE) AS
  BEGIN
    -- TAREA: Se necesita implantación para PROCEDURE PK_GESTION_CLIENTES.BAJA_AUTORIZADO
    NULL;
  END BAJA_AUTORIZADO;

  PROCEDURE MOD_AUTORIZADO(P_ID_AUTORIZADO               IN PERSONA_AUTORIZADA.ID%TYPE,
P_IDENTIFICACION   IN PERSONA_AUTORIZADA.IDENTIFICACION%TYPE,
P_NOMBRE           IN PERSONA_AUTORIZADA.NOMBRE%TYPE,
P_APELLIDOS        IN PERSONA_AUTORIZADA.APELLIDOS%TYPE, 
P_DIRECCION        IN PERSONA_AUTORIZADA.DIRECCION%TYPE,
P_FECHA_NACIMIENTO          IN PERSONA_AUTORIZADA.FECHA_NACIMIENTO%TYPE,
P_FECHA_INICIO              IN PERSONA_AUTORIZADA.FECHA_INICIO%TYPE,
P_ESTADO                    IN PERSONA_AUTORIZADA.ESTADO%TYPE,
P_FECHA_FIN                 IN PERSONA_AUTORIZADA.FECHA_FIN%TYPE,
P_TIPO   IN AUTORIZACION.TIPO%TYPE,
P_ID_EMPRESA IN AUTORIZACION.EMPRESA_ID%TYPE) IS

AUTORIZADO_ID  PERSONA_AUTORIZADA.ID%TYPE;
AUX INTEGER;
  BEGIN
  
    SELECT ID INTO AUTORIZADO_ID FROM PERSONA_AUTORIZADA WHERE ID LIKE P_ID_AUTORIZADO;
    -- CHECK DE EXISTENCIA DE AUTORIZADO (HABIA UN ERROR)
    IF AUTORIZADO_ID IS NULL THEN 
        RAISE AUTORIZADO_NO_EXISTENTE_EXCEPTION;
    END IF;
    
    IF P_IDENTIFICACION IS NOT NULL THEN
        SELECT COUNT(IDENTIFICACION) INTO AUX FROM PERSONA_AUTORIZADA WHERE IDENTIFICACION LIKE P_IDENTIFICACION;
        IF AUX > 0 THEN
            RAISE DATOS_INCORRECTOS_EXCEPTION;
        ELSE
            UPDATE PERSONA_AUTORIZADA
            SET
                    IDENTIFICACION = P_IDENTIFICACION
            WHERE
                    ID = P_ID_AUTORIZADO;
        END IF;
    END IF;
    IF P_NOMBRE IS NOT NULL THEN
        UPDATE PERSONA_AUTORIZADA
            SET
                    NOMBRE = P_NOMBRE
            WHERE
                    ID = P_ID_AUTORIZADO;
    END IF;
    IF P_APELLIDOS IS NOT NULL THEN
        UPDATE PERSONA_AUTORIZADA
            SET
                    APELLIDOS = P_APELLIDOS
            WHERE
                    ID = P_ID_AUTORIZADO;
    END IF;
    IF P_DIRECCION IS NOT NULL THEN
        UPDATE PERSONA_AUTORIZADA
            SET
                    DIRECCION = P_DIRECCION
            WHERE
                    ID = P_ID_AUTORIZADO;
    END IF;
    IF P_FECHA_NACIMIENTO IS NOT NULL THEN
        UPDATE PERSONA_AUTORIZADA
            SET
                    FECHA_NACIMIENTO = P_FECHA_NACIMIENTO
            WHERE
                    ID = P_ID_AUTORIZADO;
    END IF;
    IF P_FECHA_INICIO IS NOT NULL THEN
        UPDATE PERSONA_AUTORIZADA
            SET
                    DIRECCION = P_DIRECCION
            WHERE
                    ID = P_ID_AUTORIZADO;
    END IF;
    IF P_ESTADO IS NOT NULL THEN
        UPDATE PERSONA_AUTORIZADA
            SET
                    ESTADO = P_ESTADO
            WHERE
                    ID = P_ID_AUTORIZADO;
    END IF;
    IF P_FECHA_FIN IS NOT NULL THEN
        UPDATE PERSONA_AUTORIZADA
            SET
                    FECHA_FIN = P_FECHA_FIN
            WHERE
                    ID = P_ID_AUTORIZADO;
    END IF;
    

  END MOD_AUTORIZADO;

PROCEDURE ELIMINAR_AUTORIZADO(
P_PERSONA_AUTORIZADA_ID         IN AUTORIZACION.PERSONA_AUTORIZADA_ID%TYPE,
P_EMPRESA_ID                    IN AUTORIZACION.EMPRESA_ID%TYPE)
IS 
PERSONA_AUTORIZADA_ID_AUX        PERSONA_AUTORIZADA.ID%TYPE;
ESTADO_PERSONA                   PERSONA_AUTORIZADA.ESTADO%TYPE;
EMPRESA_ID_AUX                       AUTORIZACION.EMPRESA_ID%TYPE;
CONT_AUT_EMP                    INTEGER;
CONT_AUT_GEN                    INTEGER;
BEGIN

    -- CHECK DE QUE LA PERSONA AUTORIZADA EXISTE
    SELECT ID INTO PERSONA_AUTORIZADA_ID_AUX FROM PERSONA_AUTORIZADA WHERE ID LIKE P_PERSONA_AUTORIZADA_ID;
    SELECT ESTADO INTO ESTADO_PERSONA FROM PERSONA_AUTORIZADA WHERE ID LIKE PERSONA_AUTORIZADA_ID_AUX;
    IF PERSONA_AUTORIZADA_ID_AUX IS NULL THEN
        RAISE PERSONA_AUTORIZADA_NO_EXISTENTE_EXCEPTION;
    END IF;
    --CHECK DE QUE LA EMPRESA EXISTE
    SELECT ID INTO EMPRESA_ID_AUX FROM CLIENTE WHERE ID LIKE P_EMPRESA_ID;
    IF EMPRESA_ID_AUX IS NULL THEN 
        RAISE EMPRESA_NO_EXISTENTE_EXCEPTION;
    END IF;
    -- CHECK DE QUE EL ESTADO NO SEA YA BORRADO
    IF ESTADO_PERSONA LIKE 'BORRADO' THEN
        RAISE PERSONA_YA_BORRADA_EXCEPTION;
    END IF;
    -- CHECK DE LAS AUTORIZACIONES QUE TIENE LA PERSONA AUTORIZADA CON LA EMPRESA + BORRARLAS SI TIENE
    SELECT COUNT(PERSONA_AUTORIZADA_ID) INTO CONT_AUT_EMP FROM AUTORIZACION WHERE EMPRESA_ID LIKE EMPRESA_ID_AUX AND PERSONA_AUTORIZADA_ID LIKE PERSONA_AUTORIZADA_ID_AUX;
    IF CONT_AUT_EMP > 0 THEN 
        DELETE  FROM AUTORIZACION 
        WHERE   PERSONA_AUTORIZADA_ID LIKE PERSONA_AUTORIZADA_ID_AUX AND
                EMPRESA_ID LIKE EMPRESA_ID_AUX;
    ELSE 
        RAISE SIN_AUTORIZACIONES_EXCEPTION;
    END IF;

    -- CHECK DE LAS AUTORIZACIONES QUE TIENE LA PERSONA EN GENERAL. (SI TIENE 0 SE BORRA LA PERSONA AUTORIZADA)
    SELECT COUNT(PERSONA_AUTORIZADA_ID) INTO CONT_AUT_GEN FROM AUTORIZACION WHERE PERSONA_AUTORIZADA_ID LIKE PERSONA_AUTORIZADA_ID_AUX;
    IF CONT_AUT_GEN <= 0 THEN
        UPDATE PERSONA_AUTORIZADA
        SET
            ESTADO = 'BORRADO',
            FECHA_FIN = SYSDATE
        WHERE
            ID = PERSONA_AUTORIZADA_ID_AUX;
    END IF;
END ELIMINAR_AUTORIZADO;

END PK_GESTION_CLIENTES;