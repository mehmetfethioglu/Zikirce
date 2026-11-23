using System.Buffers.Binary;
using System.Text;
using HasibuBranchBridge.Protocol;
using Xunit;

namespace HasibuBranchBridge.Tests;

public class TenfeiZkProtocolTests
{
    [Fact]
    public void ComputeChecksumAndBuildTcpFrame_ProducesValidHeader()
    {
        var frame = TenfeiZkClient.BuildTcpFrame(TenfeiZkClient.CmdConnect, sessionId: 0, replyId: 1, payload: Array.Empty<byte>());
        Assert.Equal(16, frame.Length);
        Assert.Equal(new byte[] { 0x50, 0x50, 0x82, 0x7D }, frame[..4]);
        Assert.Equal(8u, BinaryPrimitives.ReadUInt32LittleEndian(frame.AsSpan(4, 4)));
        Assert.Equal(TenfeiZkClient.CmdConnect, BinaryPrimitives.ReadUInt16LittleEndian(frame.AsSpan(8, 2)));
        // Checksum doğrulaması: tüm ZK başlığı (crc dahil) toplamının 1'e tümleyeni 0 olmalıdır.
        Assert.Equal(0, TenfeiZkClient.ComputeChecksum(frame.AsSpan(8)));
    }

    [Fact]
    public void MakeCommKey_ProducesDeterministicFourBytes()
    {
        var bytes = TenfeiZkClient.MakeCommKey(437029, sessionId: 1234, ticks: 50);
        Assert.Equal(4, bytes.Length);
        Assert.Equal(50, bytes[2]);
    }

    [Fact]
    public void DecodeAttendanceBuffer_Filters120SecDuplicatesAndMarksCheckOutAfter30Min()
    {
        static uint EncodeZkTime(DateTime dt) =>
            (uint)((((((dt.Year - 2000) * 12 + (dt.Month - 1)) * 31 + (dt.Day - 1)) * 24 + dt.Hour) * 60 + dt.Minute) * 60 + dt.Second);

        static byte[] MakeRecord(string pin, DateTime dt, byte status = 0, byte verifyType = 15)
        {
            var rec = new byte[40];
            Encoding.ASCII.GetBytes(pin).CopyTo(rec, 2);
            rec[26] = verifyType;
            BinaryPrimitives.WriteUInt32LittleEndian(rec.AsSpan(27, 4), EncodeZkTime(dt));
            rec[31] = status;
            return rec;
        }

        var t1 = new DateTime(2026, 11, 22, 8, 30, 15);
        var tDup = new DateTime(2026, 11, 22, 8, 31, 0); // 45 sn sonra -> elenmeli
        var tOut = new DateTime(2026, 11, 22, 17, 45, 5); // 30+ dk sonra -> çıkış

        var buffer = new List<byte>();
        buffer.AddRange(MakeRecord("101", t1));
        buffer.AddRange(MakeRecord("101", tDup));
        buffer.AddRange(MakeRecord("101", tOut));

        var logs = TenfeiZkClient.DecodeAttendanceBuffer(buffer.ToArray(), branchId: 38, deviceNo: 2);
        Assert.Equal(2, logs.Count);
        Assert.Equal("38_00101_20261122_0830", logs[0].Id);
        Assert.True(logs[0].IsCheckIn);
        Assert.Equal("face", logs[0].VerifyMethod);
        Assert.Equal("38_00101_20261122_1745", logs[1].Id);
        Assert.False(logs[1].IsCheckIn);
        Assert.Equal(string.Empty, logs[0].IntegrityHash);
    }

    [Fact]
    public void DecodeUserBuffer_DecodesCp1254TurkishNames()
    {
        var rec = new byte[72];
        BinaryPrimitives.WriteUInt16LittleEndian(rec.AsSpan(0, 2), 14);
        // "ŞİRİN ĞÜ" CP1254 byte karşılıkları: Ş=0xDE, İ=0xDD, R='R', İ=0xDD, N='N', ' ', Ğ=0xD0
        var nameBytes = new byte[] { 0xDE, 0xDD, (byte)'R', 0xDD, (byte)'N', (byte)' ', 0xD0, 0xFC, 0xFE, 0xFD, 0xF0 };
        nameBytes.CopyTo(rec, 11);
        Encoding.ASCII.GetBytes("42").CopyTo(rec, 48);

        var users = TenfeiZkClient.DecodeUserBuffer(rec);
        Assert.Single(users);
        Assert.Equal("00042", users[0].CardNo);
        Assert.Equal("ŞİRİN Ğüşığ", users[0].FullName);
    }

    [Fact]
    public void ParseRealtimeEvent_MatchesBatchDeterministicIdFormat()
    {
        var payload = new byte[36];
        Encoding.ASCII.GetBytes("101").CopyTo(payload, 0);
        payload[24] = 15; // face
        payload[25] = 0;  // check-in
        payload[26] = 26; // 2026
        payload[27] = 11;
        payload[28] = 22;
        payload[29] = 8;
        payload[30] = 30;
        payload[31] = 45;

        var rt = TenfeiZkClient.ParseRealtimeEvent(payload, branchId: 38, machineNo: 2);
        Assert.NotNull(rt);
        Assert.Equal("38_00101_20261122_0830", rt!.Id);
        Assert.Equal("00101", rt.CardNo);
        Assert.True(rt.IsCheckIn);
        Assert.Equal("2026-11-22T08:30:45.000", rt.Timestamp);
        Assert.Equal(string.Empty, rt.IntegrityHash);
    }
}
