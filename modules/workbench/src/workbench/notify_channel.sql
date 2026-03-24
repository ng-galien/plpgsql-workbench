CREATE OR REPLACE FUNCTION workbench.notify_channel()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  PERFORM pg_notify('workbench_channel_' || NEW.to_module, json_build_object(
    'id', NEW.id,
    'from_module', NEW.from_module,
    'to_module', NEW.to_module,
    'msg_type', NEW.msg_type,
    'subject', NEW.subject,
    'priority', NEW.priority,
    'body', left(NEW.body, 500)
  )::text);
  RETURN NEW;
END;
$function$;
