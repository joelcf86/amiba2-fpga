-- Blink LED para AMIBA 2 (Spartan-6 XC6SLX9-2FTG256)
-- 50 MHz en E7 ; LEDs D1 cátodo común (activos en alto): R=N1, G=P1
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity blink is
  port (
    clk   : in  std_logic;   -- 50 MHz
    led_r : out std_logic;   -- D1 rojo
    led_g : out std_logic;   -- D1 verde
    led_b : out std_logic    -- D1 Azul
  );
end blink;

architecture rtl of blink is
  constant DIV : unsigned(24 downto 0) := to_unsigned(33_554_431, 25);
  signal cnt : unsigned(24 downto 0) := (others => '0');
  signal fase : unsigned(1 downto 0):= "00";
begin
  process (clk)
  begin
    if rising_edge(clk) then
      if cnt  = DIV then
        cnt <= (others => '0');
        if fase =   2 then
          fase <= "00";
        else 
          fase <= fase + 1;
        end if;
      else
        cnt <= cnt + 1;
      end if;
    end if;
  end process;

  -- cnt(24) cambia de estado cada 2^25/50e6 = 0.671 s
  ilumination: process(fase)
  begin
    led_r <= '0';led_g<='0';led_b<='0';
    case fase is
      when "00" => led_r <= '1';
      when "01" => led_g <= '1';
      when others => led_b <= '1';
    end case;
  end process;
end rtl;
